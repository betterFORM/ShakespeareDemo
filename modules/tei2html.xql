module namespace tei2="http://exist-db.org/xquery/app/tei2html";

declare namespace tei="http://www.tei-c.org/ns/1.0";

declare function tei2:tei2html($nodes as node()*) {
    for $node in $nodes
    return
        element{'div'}
        {$node/@*, attribute {'class'}{local-name($node)}
        , 
        for $child in $node/node()
            return
                if ($child instance of element())
                    then tei2:tei2html($child)
                    else $child
        }
};


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
            { tei2:tei2html($pubStmt/*) }
        </div>
};