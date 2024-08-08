return [==[           var tokens = this.getTokenizer().getLineTokens(line.trim(), state).tokens;
    
            if (!tokens || !tokens.length)
                return false;
    
            return (tokens[0].type == "keyword" && outdentKeywords.indexOf(tokens[0].value) != -1);
        };
    
        this.autoOutdent = function(state, session, row) {
            var prevLine = session.getLine(row - 1);
            var prevIndent = this.$getIndent(prevLine).length;
            var prevTokens = this.getTokenizer().getLineTokens(prevLine, "start").tokens;
            var tabLength = session.getTabString().length;
            var expectedIndent = prevIndent + tabLength * getNetIndentLevel(prevTokens);
            var curIndent = this.$getIndent(session.getLine(row)).length;
            if (curIndent < expectedIndent) {
                return;
            }
            session.outdentRows(new Range(row, 0, row + 2, 0));
        };
        this.createWorker = function(session) {
            var worker = new WorkerClient(["ace"], "ace/mode/glua_worker", "Worker");
            worker.attachToDocument(session.getDocument());
            
            return worker;
        };
    
        this.$id = "ace/mode/glua";
         
        this.completer = {
                "getCompletions":function(state, session, pos, prefix, cb) {
                    var completions = session.$mode.getCompletions(state, session, pos, prefix);
                    cb(null, completions);
                }, "identifierRegexps":Array( ID_REGEX, ID_REGEX2 )
        };
        
    }).call(Mode.prototype);
    
    exports.Mode = Mode;
    });
    ]==]