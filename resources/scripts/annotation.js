var Annotations = Annotations || {};

/**
 * Namespace function. Required by all other classes.
 */
Annotations.namespace = function (ns_string) {
    var parts = ns_string.split('.'), parent = Annotations, i;
    if (parts[0] == "Annotations") {
        parts = parts.slice(1);
    }
    for (i = 0; i < parts.length; i++) {
        // create a property if it doesn't exist
        if (typeof parent[parts[i]] == "undefined") {
            parent[parts[i]] = {};
        }
        parent = parent[parts[i]];
    }
    return parent;
};

Annotations.namespace("Annotations.Selection");

Annotations.Selection = (function () {
    Constr = function(cssMatcher) {
        var self = this;

        // setup TEI Editor
        $("#saveTeiAnnotation").on("click", function(){
            console.log("calling this.saveCreateAnnotation()");
            self.saveCreateAnnotation();
        });
        $("#cancelTeiAnnotation").on("click", function(){ $("#teiEditor").hide(); });

        // setup mouse listener 
        console.log("cssMatcher to add mouselistener to: ", cssMatcher);
        this.setupMouseListener(cssMatcher);
    };


    /*#
     # Function to handle users text selection
     #*/
    Constr.prototype.setupMouseListener = function(cssMatcher) {
        // console.log("setup Mouselistener");
        var self = this;
        $( cssMatcher ).mouseup(function() {
            $("#teiEditor").hide();
            var selection = rangy.getSelection();
            var text = selection.toString();
            var html = selection.toHtml();
            var anchorNode = selection.anchorNode;
            var anchorOffset = selection.anchorOffset;
            var focusNode = selection.focusNode;
            var focusOffset = selection.focusOffset;
            console.log("selection: ", selection);
            console.log("selection.isBackwards: ", selection.isBackwards());
            // console.log("selection.inspect(): ", selection.inspect());
            // console.log("selection.getName(): ", selection.getName());
            // console.log("selection.nativeSelection: ", selection.nativeSelection);
            // self.printProperties(selection);

            // Case 1: Nothing was selected
            if(text === "" && html === ""){
                console.log("no Text Selected");
            }
            // 
            else if(anchorNode.isEqualNode(focusNode)){
                console.log("selected Text is within the same node. TEI node xml:id: ", $(anchorNode.parentNode).attr('xml:id'));

                if($(anchorNode.parentNode).text() == text){
                    console.log("whole TEI node was selected");
                    // open surrounding TEI Node in Editor
                    self.showTeiEditor(anchorNode.parentNode)
                }
                else {
                    console.log("selected characters of TEI node:", text);
                }
            }
            else if(anchorOffset == 0 && focusOffset == 0){
                console.log("focus and anchor offset are 0");
                self.showTeiEditor(anchorNode.parentNode);
                self.showTeiEditor(anchorNode.parentNode)
            }else if($(html).text() == $(focusNode).text()){
                console.log("sel.html.text() equals focusNode.text()");
                self.showTeiEditor(anchorNode.parentNode)
            }

            else {
                console.log("parent nodes of selection are different");
                self.printProperties(selection);
            }
        });
    };

    Constr.prototype.saveCreateAnnotation = function() {
        console.log("saveCreateAnnotation");
        //do your own request an handle the results
        $.ajax({
            url: "../modules/annotate.xql",
            type: 'post',
            data: $("#teiEditorForm").serialize(),
            success: function(data) {
                console.log("date: ", data);
                return false;
            }
        });
    };

    /*#
     # Position and show the TEI Editor
     #*/
    Constr.prototype.showTeiEditor = function(node) {
        var teiNode = $(node);
        var teiEditor= $("#teiEditor");
        // extract tei type
        var teiType = teiNode.attr("class");
        var xmlId = teiNode.attr('xml:id');

        // adjust the TEI Type Select
        console.log("TEI Type Selection: ", teiType);
        $("#teiTypeSelector").val(teiType);
        $("#teiTypeValue").val(teiNode.text());
        $("#teiXmlId").val(xmlId);

        // position the tei editor
        var teiPos = teiNode.position();
        console.log("teiPos:", teiPos);
        var leftPos = teiPos.left + teiNode.width();
        var topPos = teiPos.top + teiNode.height();

        teiEditor.css({left:leftPos,top:topPos});
        teiEditor.show();

    };


    /*#
     # Function to print relevant rangy attributes to the js console
     #*/
    Constr.prototype.printProperties = function(selection) {
        var text = selection.toString();
        var html = selection.toHtml();
        var anchorNode = selection.anchorNode;
        var anchorOffset = selection.anchorOffset;
        var focusNode = selection.focusNode;
        var focusOffset = selection.focusOffset;
        console.log("sel.toString(): '", text,"'");
        console.log("sel.toHtml(): '", html,"'");
        console.log("sel.anchorNode:", anchorNode);
        console.log("sel.anchorOffset:", anchorOffset);
        console.log("sel.focusNode:", focusNode);
        console.log("sel.focusOffset:", focusOffset);
        console.log("sel.anchorNode.parentNode:", anchorNode.parentNode);
        var pointsAreEqual = rangy.dom.comparePoints(anchorNode, anchorOffset, focusNode, focusOffset);
        console.log("pointsAreEqual: ",pointsAreEqual);
    };

    return Constr;
}());