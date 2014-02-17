xquery version "3.0";

module namespace tei2="http://exist-db.org/xquery/app/tei2html";

import module namespace config="http://exist-db.org/apps/shakes/config" at "config.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace a8n="http://www.betterform.de/projects/mopane/annotation";

declare variable $tei2:format := 'html';

declare function tei2:tei2html($nodes as node()*, $layer as xs:string, $format as xs:string) {
    for $node in $nodes
        return
            let $node := 
                if ($format eq 'html')
                then tei2:tei2div($node, $layer, $format)
                else $node
            let $top-level-a8ns := 
                if ($layer eq 'feature')
                then tei2:get-feature-a8ns($node)
                else tei2:get-edition-a8ns($node)
            let $built-up-a8ns := 
                if ($format eq 'html')
                then $top-level-a8ns
                else tei2:build-up-annotations($top-level-a8ns, collection($config:a8ns)/*)
            let $collapsed-a8ns := 
                if ($format eq 'html')
                then $built-up-a8ns 
                else tei2:collapse-annotations($built-up-a8ns)
            let $meshed-a8ns := 
                if ($top-level-a8ns) 
                then tei2:mesh-annotations($node, $collapsed-a8ns, $layer, $format)
                else $node
            return
                $meshed-a8ns
};

declare function tei2:tei2div($nodes as node()*, $layer as xs:string, $format as xs:string) {
    for $node in $nodes
    return
        element{'div'}
        {$node/@*, attribute {'class'}{local-name($node)}
        , 
        for $child in $node/node()
            return
                if ($child instance of element())
                    then tei2:tei2html($child, $layer, $format)
                    else $child
        }
};

declare function tei2:get-edition-a8ns($element as element()) {
    let $element-id := $element/@xml:id/string()
    let $top-level-edition-a8ns := collection($config:a8ns)/a8n:annotation[a8n:target/@type eq 'range'][a8n:target/@layer eq 'edition'][a8n:target/a8n:id[. eq $element-id]]
    return 
        $top-level-edition-a8ns 
};

declare function tei2:get-feature-a8ns($element as element()) {
    let $element-id := $element/@xml:id/string()
    let $top-level-feature-a8ns := collection($config:a8ns)/a8n:annotation[a8n:target/@type eq 'range'][a8n:target/@layer ne 'edition'][a8n:target/a8n:id[. eq $element-id]]
    return 
        $top-level-feature-a8ns 
};

(:unused function:)
declare function tei2:header($header as element(tei:teiHeader)) {
    let $titleStmt := $header//tei:titleStmt
    let $pubStmt := $header//tei:publicationStmt
    return
        <div class="play-header">
            <h1><a href="plays/{$header/ancestor::tei:TEI/@xml:id}.html">{$titleStmt/tei:title/text()}</a></h1>
            <h2>By {$titleStmt/tei:author/text()}</h2>
            <ul>
            {
                for $resp in $titleStmt/tei:respStmt
                return
                    <li>{$resp/tei:resp/text()}: {$resp/tei:name/text()}</li>
            }
            </ul>
            { tei2:tei2html($pubStmt/*, 'feature', 'html') }
        </div>
};

(: This function takes a sequence of top-level text-critical annotations, i.e annotations of @type 'range' and @layer 'edition', and inserts as children all annotations that refer to them through their @xml:id, recursively:)
declare function tei2:build-up-annotations($top-level-critical-annotations as element()*, $annotations as element()*) as element()* {
    for $annotation in $top-level-critical-annotations
        let $annotation-id := $annotation/@xml:id
        let $annotation-element-name := local-name($annotation//body/*)
        let $children := $annotations/annotation[target/annotation-layer/id = $annotation-id]
        let $children :=
            for $child in $children
                let $child-id := $annotation/@xml:id/string()
                    return
                        if ($annotations/annotation[target/annotation-layer/id = $child-id])
                        then tei2:build-up-annotations($child, $annotations)
                        else $child
            return 
                local:insert-elements($annotation, $children, $annotation-element-name,  'first-child')            
};

(: This function inserts elements supplied as $new-nodes at a certain position, determined by $element-names-to-check and $location, or removes the $element-names-to-check globally :)
declare function local:insert-elements($node as node(), $new-nodes as node()*, $element-names-to-check as xs:string+, $location as xs:string) {
        if ($node instance of element() and local-name($node) = $element-names-to-check)
        then
            if ($location eq 'before')
            then ($new-nodes, $node) 
            else 
                if ($location eq 'after')
                then ($node, $new-nodes)
                else
                    if ($location eq 'first-child')
                    then element {node-name($node)}
                        {
                            $node/@*
                            ,
                            $new-nodes
                            ,
                            for $child in $node/node()
                                return $child
                        }
                    else
                        if ($location eq 'last-child')
                        then element {node-name($node)}
                            {
                                $node/@*
                                ,
                                for $child in $node/node()
                                    return $child 
                                ,
                                $new-nodes
                            }
                        else () (:The $element-to-check is removed if none of the four options, e.g. 'remove', are used.:)
        else
            if ($node instance of element()) 
            then
                element {node-name($node)} 
                {
                    $node/@*
                    ,
                    for $child in $node/node()
                        return 
                            local:insert-elements($child, $new-nodes, $element-names-to-check, $location) 
                }
            else $node
};


declare function tei2:collapse-annotations($built-up-critical-annotations as element()*) {
    for $annotation in $built-up-critical-annotations
        return 
            tei2:collapse-annotation(tei2:collapse-annotation(tei2:collapse-annotation($annotation, 'annotation'), 'body'), 'base-layer')
};

(: This function takes a built-up annotation and 1) collapses it, i.e. removes levels from the hierarchy by substituting elements with their children, 2) removes unneeded elements, and 3) takes the string values of terminal text-critical elements that have child feature annotations. :)
declare function tei2:collapse-annotation($element as element(), $strip as xs:string+) as element() {
    element {node-name($element)}
    {$element/@*,
        for $child in $element/node()
            return
                if ($child instance of element() and local-name($child) = $strip)
                then for $child in $child/*
                    return 
                        tei2:collapse-annotation(($child), $strip)
                else
                    if ($child instance of element() and local-name($child) = ('layer-offset-difference', 'authoritative-layer')) (:we have no need for these two elements:)
                    then ()
                    else
                        if ($child instance of element() and local-name($child) = 'target' and local-name($child/parent::element()) ne 'annotation') (:remove all target elements that are not at the base level:)
                        then ()
                        else
                            if ($child instance of element() and local-name($child/..) = ('lem', 'rdg', 'sic', 'reg') ) (:take string value of elements that are below terminal elements concerned with edition:)
                            then string-join($child//text(), ' ') (:This is a hack (@token should be used) but in real life text-critical annotations will not have sibling children with text nodes, so this is only relevant to round-tripping with annotations that mix text-critical and feature annotations.:)
                            else
                                if ($child instance of text())
                                then $child
                                else tei2:collapse-annotation($child, $strip)
      }
};

(: This function merges the collapsed annotations with the base text. A sequence of slots (<segment/>) double the number of annotations plus 1 are created; the annotations are filled in the even slots and the text, with ranges calculated from the previous and following annotations, are filled in the uneven slots (uneven slots with empty strings can occur, but even slots all have annotations). :)
declare function tei2:mesh-annotations(
    $base-text as element(), $annotations as element()*, $layer as xs:string, $format as xs:string) as node()+ {
let $segment-count := (count($annotations) * 2) + 1
let $segments :=
    for $segment at $i in 1 to $segment-count
        return
            <segment>{attribute n {$i}}</segment>
let $segments := 
        for $segment in $segments
            return
                if (number($segment/@n) mod 2 eq 0) (:an annotation:)
                then
                    let $annotation-n := $segment/@n/number() div 2
                    let $annotation := $annotations[$annotation-n]
                    let $annotation-start := number($annotation//a8n:start)
                    let $annotation-offset := number($annotation//a8n:offset)
                    let $annotation-body-child := $annotation/(* except a8n:target)
                    let $annotation-body-child := 
                        if ($tei2:format eq 'html')
                        then local-name($annotation-body-child/*)
                        else local-name($annotation-body-child)
                    let $annotated-string := substring($base-text, $annotation-start, $annotation-offset)
                    let $annotation := 
                        element{'span'}
                        {
                        attribute class {$annotation-body-child}
                        ,
                        attribute xml:id {$annotation/@xml:id/string()}
                        ,
                        attribute title {$annotation-body-child}
                        , 
                        $annotated-string}
                    return
                        local:insert-elements($segment, $annotation, 'segment', 'first-child')
                else (:a text node:)
                    <segment n="{$segment/@n/string()}">
                        {
                            let $segment-n := number($segment/@n)
                            let $previous-annotation-n := ($segment-n - 1) div 2
                            let $following-annotation-n := ($segment-n + 1) div 2
                            let $start := 
                                if ($segment-n eq $segment-count) (:if it is the last text node:)
                                then 
                                    $annotations[$previous-annotation-n]/a8n:target/a8n:start/number() 
                                    + 
                                    $annotations[$previous-annotation-n]/a8n:target/a8n:offset/number()
                                    (:the start position is the length of of the base text minus the end position of the previous annotation plus 1:)
                                else
                                    if (number($segment/@n) eq 1) (:if it is the first text node:)
                                    then 1 (:start with position 1:)
                                    else 
                                        $annotations[$previous-annotation-n]/a8n:target/a8n:start/number() 
                                        + 
                                        $annotations[$previous-annotation-n]/a8n:target/a8n:offset/number()
                                        (:if it is not the first or last text node, 
                                        start with the position of the previous annotation plus its offset plus 1:)
                            let $offset := 
                                if ($segment-n eq count($segments))  (:if it is the last text node:)
                                then 
                                    string-length($base-text) 
                                    - 
                                    (
                                    $annotations[$previous-annotation-n]/a8n:target/a8n:start/number() 
                                    + 
                                    $annotations[$previous-annotation-n]/a8n:target/a8n:offset/number()
                                    )
                                    + 
                                    1 
                                (:if it is the last text node, then the offset is the length of the base text minus the end position of the last annotation plus 1:)
                                else
                                    if ($segment-n eq 1) (:if it is the first text node:)
                                    then 
                                        $annotations[$following-annotation-n]/a8n:target/a8n:start/number()
                                        -
                                        1
                                        (:if it is the first text node, the the offset is the start position of the following annotation minus 1:)
                                    else 
                                        $annotations[$following-annotation-n]/a8n:target/a8n:start/number() 
                                        - 
                                        (
                                        $annotations[$previous-annotation-n]/a8n:target/a8n:start/number() 
                                        + 
                                        $annotations[$previous-annotation-n]/a8n:target/a8n:offset/number()
                                        )
                                        (:if it is not the first or the last text node, then the offset is the start position of the following annotation minus the end position of the previous annotation :)
                            return
                                if (number($start) and number($offset))
                                then substring($base-text, $start, $offset)
                                else ''
                            
                        }
                    </segment>
let $segments :=
    for $segment in $segments
            return
                if ($segment/@n mod 2 eq 0)
                then $segment/*
                else $segment/string()
    return 
        element {node-name($base-text)}{$base-text/@*, $segments}
};