bin        = $(shell npm bin)
lsc        = $(bin)/lsc
browserify = $(bin)/browserify
groc       = $(bin)/groc
uglify     = $(bin)/uglifyjs
VERSION    = $(shell node -e 'console.log(require("./package.json").version)')


lib: src/*.ls
	$(lsc) -o lib -c src/*.ls

dist:
	mkdir -p dist

dist/parsing.combinators.umd.js: compile dist
	$(browserify) lib/index.js --standalone folktale.parsing.combinators > $@

dist/parsing.combinators.umd.min.js: dist/parsing.combinators.umd.js
	$(uglify) --mangle - < $^ > $@

# ----------------------------------------------------------------------
bundle: dist/parsing.combinators.umd.js

minify: dist/parsing.combinators.umd.min.js

compile: lib

documentation:
	$(groc) --index "README.md"                                              \
	        --out "docs/literate"                                            \
	        src/*.ls test/*.ls test/specs/**.ls README.md

clean:
	rm -rf dist build lib

test:
	$(lsc) test/tap.ls

package: compile documentation bundle minify
	mkdir -p dist/parsing.combinators-$(VERSION)
	cp -r docs/literate dist/parsing.combinators-$(VERSION)/docs
	cp -r lib dist/parsing.combinators-$(VERSION)
	cp dist/*.js dist/parsing.combinators-$(VERSION)
	cp package.json dist/parsing.combinators-$(VERSION)
	cp README.md dist/parsing.combinators-$(VERSION)
	cp LICENCE dist/parsing.combinators-$(VERSION)
	cd dist && tar -czf parsing.combinators-$(VERSION).tar.gz parsing.combinators-$(VERSION)

publish: clean
	npm install
	npm publish

bump:
	node tools/bump-version.js $$VERSION_BUMP

bump-feature:
	VERSION_BUMP=FEATURE $(MAKE) bump

bump-major:
	VERSION_BUMP=MAJOR $(MAKE) bump


.PHONY: test
