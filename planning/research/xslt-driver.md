# Research: xslt-driver

_Auto-captured from the 2026-09-02 research workflow. Verified findings only —
see `verify-corrections.md` for what the adversarial pass overturned._

## Summary

A-Z+T's XLingPaper path (`io_put/xlp.py`) is a usable template for a Dekereke transform driver — defensive `import lxml.etree` inside the method, a transforms dir from `utilities/file.py`, a list of stylesheets parsed into `lxml.etree.XSLT` objects, per-stylesheet `error_log` draining, and one Python interlude mid-chain. But two things must be said bluntly. (1) That precedent is DEAD CODE: `file.gettransformsdir()` (utilities/file.py:166-170) resolves `xlptransforms` against `utilities/`, not the repo root, so it returns the string `'HELP! not sure why /Users/Seth/GIT/azt/utilities/xlptransforms is not there!'` and `xlp.Report.compile()` bails at xlp.py:114-116 every time — confirmed by running it. Copy the *shape*, not the path helper; use `file.pathname_from_base_dir()` (file.py:104-106) instead. (2) lxml here is libxslt 1.1.43 = XSLT 1.0 + EXSLT, and 1.0 handles the hard parts of this job better than expected: I wrote and RAN parameterised column access (`*[name()=$col]`, `xsl:element name="{$col}"`), a document()-based side-channel for Python-generated GUIDs, and an identity-transform merge export — all against the real anonymised samples in both UTF-16LE+BOM and bare UTF-8. Verdict: XSLT is genuinely right for BOTH directions, but only if export is a MERGE onto the original Dekereke file (identity transform + role override), not a regeneration from LIFT — regeneration silently blanks every unmapped column. Four hard limits stay in Python: byte-stream handoff (encoding), GUID/timestamp generation, XML-name validation of columns, and CRLF restoration.

## Findings

- **[high]** xlp.py's XSLT chain is currently unreachable dead code: file.gettransformsdir() resolves the transforms dir against utilities/ instead of the repo root and returns an error STRING, which compile() detects and returns on.
  - _evidence:_ /Users/Seth/GIT/azt/utilities/file.py:166-170 — `def gettransformsdir():` / `dir=pathlib.Path.joinpath(pathlib.Path(__file__).parent,'xlptransforms')` / `if not os.path.exists(dir): return "HELP! not sure why {} is not there!".format(dir)`. `__file__` is utilities/file.py so parent is utilities/, but xlptransforms/ is at the repo root. Ran it: `gettransformsdir() -> 'HELP! not sure why /Users/Seth/GIT/azt/utilities/xlptransforms is not there!'` while `pathname_from_base_dir('xlptransforms') -> /Users/Seth/GIT/azt/xlptransforms` (exists). /Users/Seth/GIT/azt/io_put/xlp.py:113-116 then does `self.transformsdir=file.gettransformsdir()` / `if isinstance(self.transformsdir, str) and not file.exists(self.transformsdir): log.error(...); return`. xlp.py:75 already concedes `self.compile() #This isn't working yet.` getstylesheetdir (file.py:159-165) has the same __file__-based fallback bug.

- **[high]** The defensive-lxml precedent to copy is a function-local import with a log-and-return degrade, and lxml is treated as optional throughout the repo even though it is in requirements.txt.
  - _evidence:_ /Users/Seth/GIT/azt/io_put/xlp.py:90-95: `def compile(self):` / `try:` / `import lxml.etree` / `except ImportError:` / `log.info(_("Couldn’t find/import lxml, so not compiling report."))` / `return`. requirements.txt:21 is a bare `lxml`; utilities/py_modules.py:46 lists `['lxml']` in the pip backstop; tests/test_import_smoke.py lists 'lxml' in OPTIONAL_DEPS ("A failure to import one of these is a skip, not a regression"). io_put/lift.py:8-15 deliberately does NOT use lxml for the LIFT tree — the try-import is commented out and `lxml=False` is hard-set, with xml.etree used via utilities/xmletfns.py:15 `def readxml(filename): tree=ET.parse(filename)`.

- **[high]** lxml on this Mac is libxslt 1.1.43 — XSLT 1.0 only, plus EXSLT. EXSLT date: and math: are live.
  - _evidence:_ `python3 -c "import lxml.etree as e; print(e.LIBXML_VERSION, e.LIBXSLT_VERSION, e.LXML_VERSION)"` -> `LIBXML2 (2, 14, 4) LIBXSLT (1, 1, 43) LXML (6, 0, 0, 0)`, Python 3.11.8. libxslt has never implemented XSLT 2.0/3.0. Ran a stylesheet using `date:date-time()` (ns http://exslt.org/dates-and-times): returned `2026-09-02T08:09:05+09:00`, empty error_log. `math:random()` returned `7.82636925942561e-06`. `generate-id(/)` returned `id1`.

- **[high]** (2a) Per-database user-defined column names ARE fully expressible in XSLT 1.0 via xsl:param + *[name()=$col] on read and xsl:element name="{$col}" on write. Ran end-to-end on both real samples.
  - _evidence:_ dekereke2lift.xsl with `<xsl:param name="col.form" select="'Phonetic'"/>` and `<xsl:variable name="form" select="normalize-space(*[name()=$col.form])"/>`, driven from Python with `ET.XSLT.strparam('Phonetic')`. On SampleLang_minimal.xml (bare UTF-8): 5 entries out of 6 data_form records — the empty-<Phonetic/> record 0027 correctly dropped by `<xsl:apply-templates select="data_form[normalize-space(*[name()=$col.form]) != '']"/>`. On SampleLang_full.xml (UTF-16LE+BOM, ~40 columns): 9 entries of 10 records. Both with empty error_log. Reverse direction `<xsl:element name="{@name}">` over a mapping document produced a valid <phon_data> with the source column inventory in source order.

- **[high]** BUT xsl:element name="{$col}" RAISES XSLTApplyError on a column name that is not a valid XML QName — and Dekereke column names are free text. Python must validate the inventory before the transform or the whole export aborts mid-run.
  - _evidence:_ Ran `<xsl:element name="{$col}">v</xsl:element>` against five names: 'Orth.practice' -> OK `<Orth.practice>v</Orth.practice>`; 'IMP-re' -> OK; '2ndSpeaker' -> `XSLTApplyError: xsl:element: The effective name '2ndSpeaker' is not a valid QName.`; 'Speaker 2' -> same; 'Tone#' -> same. The two names the sample README calls out (`IMP-re`, `Orth.practice`) pass; leading-digit and space/# names do not.

- **[high]** (2b) Input encoding is entirely resolved by the parser before XSLT sees anything — the stylesheet layer never knows. The only rule is: hand lxml BYTES, never a pre-decoded str.
  - _evidence:_ `ET.fromstring(open(f,'rb').read())` parsed SampleLang_full.xml (UTF-16LE+BOM, `encoding="utf-16"` decl) and SampleLang_minimal.xml (bare UTF-8) identically, both to root `phon_data`. Pre-decoding raises: `ET.fromstring(raw.decode('utf-8'))` -> `ValueError: Unicode strings with encoding declaration are not supported. Please use bytes input or XML fragments without declaration.` — same for the utf-16 decode. This is exactly the trap /Users/Seth/dekereke-pa-data-source/sample-data/README.md warns about ("hand the raw byte stream to the XML parser"). Note A-Z+T's own utilities/xmletfns.py:15 readxml passes a FILENAME to ET.parse, which is also safe; the danger is only in a str round-trip.

- **[high]** (2c) Output encoding AND BOM are fully declarative via xsl:output — libxslt emits UTF-16LE with a BOM, which is byte-identical in kind to older Dekereke output. Zero Python needed for encoding on write.
  - _evidence:_ `<xsl:output method="xml" encoding="UTF-16"/>` then `result.write_output(path)` produced `b'\xff\xfe<\x00?\x00x\x00m\x00l\x00 \x00v\x00e\x00r\x00s\x00i\x00o\x00n\x00=\x00"\x001\x00.\x000\x00"\x00'` — UTF-16LE BOM present, matching SampleLang_full.xml's own first bytes `b'\xff\xfe<\x00?\x00x\x00m\x00l\x00...'`. `bytes(result_tree)` carries the BOM too.

- **[high]** CRLF, by contrast, CANNOT be preserved by XSLT — XML parsers normalize CRLF to LF per spec, so it must be a byte-level Python post-pass. The plan's §2.8 'preserve them on write' is therefore a driver obligation, not a stylesheet one.
  - _evidence:_ Source SampleLang_minimal.xml: `b'\r\n' in raw -> True`. After identity-merge transform and `write_output`: `CRLF count: 0, LF count: 104`. xsl:output in XSLT 1.0 has no line-ending attribute.

- **[high]** (2d) Grouping/dedup is not needed in XSLT at all: the column inventory is harvested in Python in eight lines with order-preserving dedup, and Muenchian grouping is avoided entirely. The mapping is passed in as a document, not derived in the stylesheet.
  - _evidence:_ Python harvest over SampleLang_minimal.xml gave `['Reference','Category','SoundFile','IndonesianGloss','Phonetic','Tulisan','Speaker2','kosong','Xstraight','Xbig','Xbroken','Xnearby','Xstrong','Xlike','Catatan']` in source order, skipping `qvp_acoustic_data_`. The stylesheet then just iterates `$map/col`. Muenchian grouping (`xsl:key` + `count(.|key(...)[1])=1`) would work but buys nothing, since Python already needs the inventory to build the mapping-guess UI.

- **[high]** (2e) XSLT 1.0 cannot make a GUID and cannot make A-Z+T's timestamp format. generate-id() is document-scoped ('id1'), math:random() is a float, and EXSLT date:date-time() returns local time with an offset, not A-Z+T's UTC-Z form. Both must come from Python — and lxml will NOT accept a node-set param, so the channel is document($file).
  - _evidence:_ io_put/lift.py:4917-4918 `def getnow(): return datetime.datetime.now(datetime.UTC).isoformat()[:-7]+'Z'` — UTC with a literal Z; EXSLT gave `2026-09-02T08:09:05+09:00`. io_put/lift.py:317-331 makenewguid builds `rxi(8)+'-'+rxi(4)+'-'+rxi(4)+'-'+rxi(4)+'-'+rxi(12)` from random.randint — no XSLT 1.0 equivalent. Passing an _Element as an XSLT param failed: `TypeError: Argument must be bytes or unicode, got '_Element'` (lxml/xslt.pxi:666 _convert_xslt_parameters). Replacing it with `<xsl:param name="idfile"/><xsl:variable name="guids" select="document($idfile)/guids"/>` and a Python-written side file worked: entries came out with real uuid4 GUIDs, e.g. guid="dbf813a5-c643-47f1-a4b9-f48b14abc3b4" id="oudo_dbf813a5-...".

- **[high]** Export by REGENERATION from LIFT is lossy and must not ship as the round-trip path: every column not in the mapping comes back empty.
  - _evidence:_ Ran lift2dekereke.xsl (regenerate from $map/col) on LIFT derived from SampleLang_minimal.xml. Output kept Reference/Category/SoundFile/IndonesianGloss/Phonetic but emitted `<Tulisan/> <Speaker2/> <Catatan/> <Xstraight/> <Xbig/>` — the source had `<Tulisan>oudo</Tulisan>`, `<Catatan>periksa dengan penutur lain</Catatan>`, `<Xstraight>tei dobe</Xstraight>`, `<Xbig>tei kɔi</Xbig>`.

- **[high]** Export by MERGE (identity transform over the ORIGINAL Dekereke file, overriding only mapped columns) is loss-free, preserves record order, unmapped columns, qvp_acoustic_data_ blocks and the source indentation — and is the single strongest argument for using XSLT on the export side.
  - _evidence:_ lift2dekereke_merge.xsl: `<xsl:template match="@*|node()"><xsl:copy><xsl:apply-templates select="@*|node()"/></xsl:copy></xsl:template>` plus `<xsl:template match="data_form/*">` that looks up `$map/col[@name=name()]/@role` and only substitutes on a match. Run with an A-Z+T-edited LIFT (transcription 0018 changed sika->siga, tone groups added): output kept `<Tulisan>sika</Tulisan>` and `<Catatan>ejaan belum pasti: sika / siga</Catatan>` verbatim, wrote `<Phonetic>siga</Phonetic>` and `<Speaker2>LH</Speaker2>`/`<Speaker2>HL</Speaker2>`, and left the skipped record 0027 (`<Phonetic/>`, `<kosong>x</kosong>`) fully intact. Empty error_log.

- **[high]** The merge stylesheet has a silent data-destruction trap: an entry deleted in A-Z+T makes value-of on an empty node-set return '' and BLANK the original Dekereke value. An existence guard in the xsl:when test fixes it.
  - _evidence:_ Removed the entry for Reference 0015 from the LIFT and re-ran the merge. Unguarded: `Reference 0015 Phonetic -> ''` (source was 'tei') — data loss. With the test changed to `$role='form' and $ref!='' and $lift/entry[field[@type='dekereke-reference']/form/text = $ref]`: `Reference 0015 Phonetic -> 'tei'` — preserved.

- **[high]** Cross-document lookup by predicate is O(n^2) and unusable at field scale; xsl:key with a for-each context switch into the secondary document is 187x faster and produces byte-identical output. This is a mandatory idiom, not an optimisation.
  - _evidence:_ Synthetic 3000-record Dekereke db + matching LIFT. Naive `$lift/entry[field[@type='dekereke-reference']/form/text = $ref]/...`: 11.22s. Keyed — `<xsl:key name="byref" match="entry" use="field[@type='dekereke-reference']/form/text"/>` plus `<xsl:for-each select="$lift"><xsl:value-of select="key('byref',$ref)/..."/></xsl:for-each>`: 0.06s. `identical output: True`. The for-each is required because XSLT 1.0 key() only indexes the current document; A-Z+T LIFT files reach 16 MB (io_put/lift.py:1245-1250 save-cost comment).

- **[high]** Scoping Seth's 'what LIFT does AZT produce' question: A-Z+T never creates a <lift> root element. Every project starts from an existing LIFT document (FLEx/WeSay export, or the SILCAWL template) and A-Z+T only ADDS a small, fixed set of subtrees. The Dekereke import stylesheet therefore has to emit that small set, not general LIFT.
  - _evidence:_ Grep for `Element('lift'` / `<lift ` across the repo returns nothing; io_put/lift.py:1240+ write() just re-serializes the tree read at io_put/lift.py:1170-1177 (`self.tree,self.nodes=et.readxml(self.filename)`). New projects go through io_put/cawl.py `loadCAWL()` -> `lift.LiftXML(str(stockCAWL),tostrip=True)` over `lift_templates/SILCAWL/SILCAWL.lift`, then backend/core/templates.py WordListTemplate.verify_writeable -> file.getnewlifturl (utilities/file.py:198-206).

- **[high]** The exact LIFT vocabulary A-Z+T writes is: entry[@dateCreated,@dateModified,@guid,@id] > lexical-unit (empty) + citation/form[@lang]/text + sense[@id] > grammatical-info[@value] + definition/form[@lang]/text + gloss[@lang]/text; plus sense-level field[@type='tone']/form[@lang]/text; plus pronunciation > form[@lang]/text + field[@type]/form/text + trait[@name='location'][@value].
  - _evidence:_ io_put/lift.py:344-375 addentry: `et.SubElement(self.nodes,'entry',attrib={'dateCreated':now,'dateModified':now,'guid':guid,'id':(kwargs['form'][analang]+'_'+str(guid))})`, then `'lexical-unit'` (left empty — comment at :352-353 "Just adding citation, not lexeme forms"), `citation`>`form[@lang=analang]`>`text`, `sense[@id=senseid]`>`grammatical-info[@value=ps]`, `definition`>`form[@lang=glosslang]`>`text`, `gloss[@lang=glosslang]`>`text`. io_put/lift.py:1069-1070 addtoneUF: `Node(node[0],tag='field',attrib={'type':'tone'})` + makeformnode. io_put/lift.py:1130-1136 addpronunciationfields, with the literal target in the docstring at :1145-1155. The full permitted shape is enumerated at io_put/lift.py:4553-4570 (children map) and 4571-4582 (aliases: lexeme->'lexical-unit', ps->'grammatical-info', toneUFfield->"field[@type='tone']").

- **[high]** A-Z+T stores audio as a <form lang="{analang}-Zxxx-x-audio"><text>bare.wav</text></form> sibling, NOT as <media href>. My first import stylesheet was wrong on this and I corrected it; the driver resolves the folder at runtime, never in the file.
  - _evidence:_ backend/langtags.py:43 `audio_code='-Zxxx-x-audio'`. io_put/lift.py:2881-2886: `if rel:=self.textvaluebylang(self.db.audiolang): abs=file.getdiredurl(self.db.audiodir,rel)`, with the docstring at :2871-2873 "These attributes are not stored in lift; they depend on the work environment... audiodir should be the fully qualified filesystem path". <media href> appears only at io_put/lift.py:3838 `wav=self.ph.find('media').get('href')` inside copy_ph_form_and_media_to_lc — a READ path for FLEx-produced LIFT. Re-ran the corrected stylesheet: `<citation><form lang="iau"><text>oudo</text></form><form lang="iau-Zxxx-x-audio"><text>0012_turun.wav</text></form></citation>`. This dovetails with Dekereke storing bare .wav names and the folder in the sibling -DkUserSettings.xml <sound_file_path>: both formats keep the filename in the record and the folder outside it.

- **[medium]** Latent blocker for the import path: LiftXML.makenewguid() will IndexError on a LIFT with no entries, which is exactly the state of a fresh Dekereke import if you go through addentry() rather than an XSLT bulk build.
  - _evidence:_ io_put/lift.py:328-331: `allguids=list(self.guids)+list(self.senseids)` / `guid=allguids[0]` / `while guid in allguids:` — allguids[0] on an empty list raises. The CAWL path never hits this because the SILCAWL template ships populated (io_put/cawl.py loadCAWL). This is an argument FOR the XSLT bulk build over a per-record addentry() loop, independent of the XSLT-vs-Python question.

- **[high]** document('') in XSLT 1.0 resolves to the STYLESHEET document, not to nothing — so an empty idfile param silently yields an empty node-set rather than an error, and the fallback branch fires. Works, but it is an accident the driver should not rely on.
  - _evidence:_ Ran the import stylesheet on SampleLang_full.xml with `idfile=ET.XSLT.strparam('')`: no error, and GUIDs fell through to the `concat('dk-',generate-id())` branch — first entry guid was `dk-id1`. Per XSLT 1.0 §12.1, document('') refers to the stylesheet itself.

- **[high]** xlp.py's chain is not pure XSLT — it drops out to Python between passes 3 and 4, which is direct in-repo precedent for a hybrid Dekereke driver rather than a purist all-XSLT one.
  - _evidence:_ io_put/xlp.py:159-162: `newdom=rx.texmllike(str(dom))` / `with open(outfile+'c','wb') as f: f.write(newdom.encode('utf_8'))` / `dom = lxml.etree.parse(outfile+'c') #this is where this currently breaks`. Also note the chain SKIPS transform[2] (xlp.py:143 `# newdom2 = transform[2](newdom1) #not used; always using stylesheets!`) while still compiling it in the loop at :129-140 — so the xslts list is a registry, not a strict pipeline.


## Artifact

>>> ARTIFACT — Dekereke <-> LIFT transform mechanism for A-Z+T

Everything below was executed against lxml 6.0.0 / libxslt 1.1.43 / Python 3.11.8 and the
real anonymised samples in /Users/Seth/dekereke-pa-data-source/sample-data/. Empty error_logs
unless noted.

============================================================================
1. WHAT xlp.py ACTUALLY DOES (the pattern to copy — and the bug not to copy)
============================================================================

(a) Defensive lxml import — function-local, log-and-return. io_put/xlp.py:90-95:

    def compile(self):
        try:
            import lxml.etree
        except ImportError:
            log.info(_("Couldn’t find/import lxml, so not compiling report."))
            return

  Note it is inside compile(), NOT at module scope. io_put/xlp.py imports only
  `from xml.etree import ElementTree as ET` at the top (line 6). Copy this exactly:
  io_put/dekereke.py must import cleanly with no lxml, so tests/test_import_smoke.py
  passes on a lean box (it lists 'lxml' in OPTIONAL_DEPS).

(b) Transforms dir — io_put/xlp.py:113-116:

        self.transformsdir=file.gettransformsdir()
        if isinstance(self.transformsdir, str) and not file.exists(self.transformsdir):
            log.error(self.transformsdir)
            return

  The `isinstance(..., str)` test is there because gettransformsdir returns an ERROR STRING
  on failure. utilities/file.py:166-170:

    def gettransformsdir():
        dir=pathlib.Path.joinpath(pathlib.Path(__file__).parent,'xlptransforms')
        if not os.path.exists(dir):
            return "HELP! not sure why {} is not there!".format(dir)
        return dir

  *** THIS IS BROKEN. *** __file__ is utilities/file.py, so parent is utilities/, but
  xlptransforms/ is at the REPO ROOT. Verified at runtime:
      gettransformsdir() -> 'HELP! not sure why /Users/Seth/GIT/azt/utilities/xlptransforms is not there!'
  compile() therefore returns at line 116 on every invocation. xlp.py:75 already admits
  `self.compile() #This isn't working yet.` getstylesheetdir (file.py:159-165) has the same
  __file__ fallback bug. DO NOT reuse this helper. Use, from utilities/file.py:104-106:

    def pathname_from_base_dir(filename):
        """This is full, relative to this file (in the program repo root)"""
        return pathlib.Path(source_base_dir).joinpath(filename)

  (source_base_dir is set in utilities/__init__.py, PyInstaller-aware via sys._MEIPASS.)
  io_put/cawl.py already uses it: file.pathname_from_base_dir('lift_templates/SILCAWL/SILCAWL.lift').
  Verified: pathname_from_base_dir('xlptransforms') -> /Users/Seth/GIT/azt/xlptransforms (exists).
  Optional courtesy PR to Kent: add `def getdekerekedir(): return pathname_from_base_dir('dekereke_transforms')`
  and, separately, fix gettransformsdir the same way.

(c) Stylesheet parse + error drain — io_put/xlp.py:121-140:

        transform={}
        outfile=self.filename #base for multiple files, below
        xslts=[
            (1,'XLingPapRemoveAnyContent.xsl'),
            (2,'XLingPapXeLaTeX1.xsl'),
            (3,'XLingPapPublisherStylesheetXeLaTeX.xsl'),
            (4,'TeXMLLike.xsl')
            ]
        for n,xslt in xslts:
            try:
                trans=lxml.etree.parse(str(self.transformsdir)+'/'+xslt)
            except lxml.etree.XMLSyntaxError as e:
                for entry in e.error_log:
                    log.error("{}: {} ({})".format(entry.domain_name,
                                            entry.type_name, entry.filename))
            transform[n] = lxml.etree.XSLT(trans)
            for error in transform[n].error_log:
                log.error("XSLT Error {}: {} ({})".format(error.message,
                                                    error.line, error.filename))

  Two latent flaws worth not inheriting: the except does not `continue`, so a syntax error
  falls through to XSLT(trans) with a stale/undefined `trans`; and the xslts list is a
  REGISTRY, not a strict pipeline — pass 2 is compiled but never applied (xlp.py:143
  `# newdom2 = transform[2](newdom1) #not used; always using stylesheets!`).

(d) Chaining, with a Python interlude — io_put/xlp.py:141-168:

        newdom = transform[1](dom)
        newdom.write_output(outfile+'a')
        dom=newdom
        try:
            newdom = transform[3](dom)
            newdom.write_output(outfile+'b')
        except Exception:
            for error in transform[3].error_log: ...
        dom=newdom
        newdom=rx.texmllike(str(dom))            # <-- drops out to Python mid-chain
        with open(outfile+'c', 'wb') as f:
            f.write(newdom.encode('utf_8'))
        dom = lxml.etree.parse(outfile+'c')
        ...
            newdom = transform[4](dom)
            newdom.write_output(texfile)

  The result object is passed straight into the next XSLT; `write_output(path)` honours
  xsl:output; `str(result)` serializes. The precedent for a hybrid XSLT+Python driver
  is right there at line 159. Also note `newdom.write_output(outfile+'a')` writes
  intermediates to disk — a debugging affordance worth keeping (behind a flag).

============================================================================
2. XSLT 1.0 CONSTRAINT AUDIT (measured, not reasoned)
============================================================================
libxslt 1.1.43 = XSLT 1.0 only, + EXSLT (date:, math:, exsl: all confirmed live).

(a) USER-DEFINED COLUMN NAMES — SOLVED, both directions.
    READ:  *[name()=$col]                      -> works, tested on both samples
    WRITE: <xsl:element name="{$col}">          -> works for 'IMP-re', 'Orth.practice'
    TRAP:  xsl:element RAISES XSLTApplyError on a non-QName. Measured:
             'Orth.practice' OK | 'IMP-re' OK
             '2ndSpeaker' -> XSLTApplyError: the effective name '2ndSpeaker' is not a valid QName.
             'Speaker 2'  -> same       'Tone#' -> same
    => Python MUST validate the inventory before the export transform runs.
    NOTE: use name() not local-name(); Dekereke has no namespaces, and name() is what
    round-trips a name with a '.' or '-' unchanged.

(b) INPUT ENCODING — not an XSLT concern at all. The parser resolves BOM + declaration
    before the stylesheet exists. The ONLY rule is bytes-in:
        ET.fromstring(open(f,'rb').read())            # UTF-16LE+BOM and bare UTF-8: both OK
        ET.fromstring(open(f,'rb').read().decode())   # ValueError: Unicode strings with
                                                      # encoding declaration are not supported.
    So the three live Dekereke encodings cost the stylesheet exactly zero lines.

(c) OUTPUT ENCODING/BOM — fully declarative. <xsl:output encoding="UTF-16"/> + write_output()
    produced b'\xff\xfe<\x00?\x00x\x00m\x00l\x00...' — UTF-16LE **with BOM**, the same shape
    as SampleLang_full.xml's own first bytes. Default to UTF-8 (current Dekereke release),
    swap to UTF-16 on round-trip onto an old database. Zero Python.
    NOT covered by xsl:output: CRLF. Measured CRLF count in output = 0 (source had CRLF).
    XML parsers normalize CRLF->LF per spec — no XML tool can preserve it. Byte-level
    Python post-pass, in the driver.

(d) GROUPING/DEDUP — sidestepped entirely. The column inventory is harvested in Python
    (order-preserving dedup, skipping qvp_acoustic_data_) because Python needs it anyway for
    the mapping-guess UI, and is handed to the stylesheet as a mapping document. Muenchian
    grouping (xsl:key + count(.|key(k,v)[1])=1) would work but earns nothing here.

(e) GUIDs/TIMESTAMPS — XSLT 1.0 cannot. Measured:
      generate-id(/) -> 'id1'                  (document-scoped, not a GUID)
      math:random()  -> 7.82636925942561e-06   (a float)
      date:date-time() -> '2026-09-02T08:09:05+09:00'   (LOCAL + offset)
    A-Z+T's format is UTC-with-Z: io_put/lift.py:4917-4918
      def getnow(): return datetime.datetime.now(datetime.UTC).isoformat()[:-7]+'Z'
    and its GUID is io_put/lift.py:328-331, hex 8-4-4-4-12 from random.randint.
    CHANNEL: lxml will NOT take a node-set param —
      TypeError: Argument must be bytes or unicode, got '_Element'   (lxml/xslt.pxi:666)
    So Python writes a small side document and the stylesheet reads it with document($idfile).
    Verified working. (Beware: document('') resolves to the STYLESHEET in XSLT 1.0 — an empty
    idfile silently yields an empty node-set, not an error. Always pass a real URI.)

(f) CROSS-DOCUMENT LOOKUP — the one that will bite at field scale. N=3000 records:
      naive  $lift/entry[field[@type='dekereke-reference']/form/text=$ref]/...   11.22 s
      keyed  xsl:key + <xsl:for-each select="$lift"> context switch               0.06 s
      identical output: True                                             ==> 187x
    The for-each is MANDATORY: XSLT 1.0 key() only indexes the current document.
    A-Z+T LIFT files reach 16 MB (io_put/lift.py:1245-1250).

============================================================================
3. DIVISION OF LABOUR
============================================================================
XSLT (declarative, no state, no I/O):
  * element/attribute mapping in both directions, driven by params + a mapping document
  * record filtering (empty phonetic form) — a single predicate
  * silently dropping qvp_acoustic_data_ and unmapped columns on import (no template matches)
  * identity-preserving merge on export
  * output encoding + BOM (xsl:output)
  * key()-based join between the LIFT and Dekereke documents

PYTHON (everything stateful, non-deterministic, or filesystem-touching):
  * byte-stream read of the source (2b) and the sibling -DkUserSettings.xml <sound_file_path>
  * column inventory harvest + XML-name validation (2a trap) + the mapping-guess heuristics
    and the confirmation dialog — a UI decision can never live in a stylesheet
  * GUID + dateCreated/dateModified generation into the ids side-document (2e), matching
    io_put/lift.py:328-331 and :4917-4918 exactly so A-Z+T's own code cannot tell the
    difference between an imported entry and one from addentry()
  * writing the mapping/ids side-documents and passing file: URIs as strparams
  * CRLF restoration on write (2c)
  * audio: copying/referencing .wav into the project audio dir per io_put/sound.py, and
    resolving db.audiodir at runtime (io_put/lift.py:2881-2886 — the folder is NEVER in the file)
  * lxml-missing degrade, error_log draining, logging, i18n

Rule of thumb that falls out of the measurements: if it needs the filesystem, a random
number, a clock, or a human, it is Python. Everything else is XSLT.

============================================================================
4. FILE LAYOUT (mirrors xlptransforms/)
============================================================================
  /Users/Seth/GIT/azt/dekereke_transforms/
      README.md                     # like xlptransforms/README.md
      dekereke2lift.xsl             # import
      lift2dekereke.xsl             # fresh export (regenerate) — SECOND CLASS, see verdict
      lift2dekereke_merge.xsl       # round-trip export (identity + override) — PRIMARY
  /Users/Seth/GIT/azt/io_put/dekereke.py        # thin driver, no frontend imports
  /Users/Seth/GIT/azt/backend/core/templates.py # + class Dekereke(WordListTemplate)
  /Users/Seth/GIT/azt/tests/test_dekereke.py    # fixtures generated in-test, all 3 encodings

Put the transforms at the repo ROOT next to xlptransforms/ (that is where the existing one
lives), and resolve with file.pathname_from_base_dir, never gettransformsdir.

============================================================================
5. DRIVER — io_put/dekereke.py (public surface)
============================================================================

    #!/usr/bin/env python3
    # coding=UTF-8
    """Dekereke (Rod Casali) <-> LIFT conversion. XSLT-driven, mirroring io_put/xlp.py."""
    from utilities.i18n import _
    from utilities import logsetup, file
    log=logsetup.getlog(__name__)
    from xml.etree import ElementTree as ET      # top-level: stdlib only, like xlp.py:6
    import re, uuid, datetime, pathlib

    NCNAME=re.compile(r'^[A-Za-z_][\w.\-]*$')     # XML 1.0 NCName, ASCII-safe subset
    IGNORE={'qvp_acoustic_data_'}
    AUDIO_SUFFIX='-Zxxx-x-audio'                  # backend/langtags.py:43

    class LxmlMissing(Exception): pass

    def _lxml():
        """Single defensive import point. Follows io_put/xlp.py:90-95, but RAISES so the
        caller can show the user a real message instead of silently doing nothing."""
        try:
            import lxml.etree
        except ImportError:
            log.info(_("Couldn’t find/import lxml, so not converting Dekereke data."))
            raise LxmlMissing(_("Converting Dekereke files needs the ‘lxml’ module, "
                                "which isn’t installed."))
        return lxml.etree

    def available():
        """True if Dekereke conversion can run. UI calls this to enable/disable the menu
        item, so the feature is never offered and then refused."""
        try: _lxml(); return True
        except LxmlMissing: return False

    # ---- read side (no lxml needed; stdlib ET parses all three encodings from bytes) ----
    def read(path):        -> DekerekeXML
    class DekerekeXML:
        .path, .columns (list, source order, IGNORE removed, dedup),
        .records (list[dict]), .encoding ('utf-8'|'utf-16'), .had_bom, .had_crlf,
        .audio_dir()  # sibling <basename>-DkUserSettings.xml -> <sound_file_path>; None if absent
        .bad_column_names()   # [c for c in columns if not NCNAME.match(c)] -- see 2a trap
    def column_guesses(columns) -> dict[str,list[str]]   # role -> ranked column names
                                                          # EN + ID cues; never a silent choice

    # ---- transform side ----
    def to_lift(dk, mapping, analang, glosslangs, outpath):
        """Dekereke -> LIFT. Returns outpath. Raises LxmlMissing."""
        etree=_lxml()
        src=etree.fromstring(pathlib.Path(dk.path).read_bytes())   # BYTES. never str.
        n=len(src.findall('data_form'))
        ids=ET.Element('guids')                                    # Python makes the GUIDs
        for i in range(1,n+1):
            ET.SubElement(ids,'g',n=str(i),entry=_guid(),sense=_guid())
        idfile=_side(ids,'ids.xml')
        xsl=etree.XSLT(etree.parse(str(file.pathname_from_base_dir(
                        'dekereke_transforms/dekereke2lift.xsl'))))
        for e in xsl.error_log:                                    # xlp.py:137-140
            log.error("XSLT Error {}: {} ({})".format(e.message,e.line,e.filename))
        res=xsl(src, **_params(mapping, analang, glosslangs,
                               now=_now(), idfile=idfile.as_uri()))
        res.write_output(str(outpath))
        return outpath

    def from_lift(liftpath, dk, mapping, analang, glosslang, outpath, mode='merge'):
        """LIFT -> Dekereke. mode='merge' (default, loss-free, needs dk) or 'fresh'."""
        # merge: primary input is dk's ORIGINAL bytes; the LIFT arrives via document($liftfile)
        # fresh: primary input is the LIFT; $mapfile supplies the column inventory
        # then: _restore_crlf(outpath) if dk and dk.had_crlf

    def _now():  return datetime.datetime.now(datetime.UTC).isoformat()[:-7]+'Z'   # lift.py:4918
    def _guid(): return str(uuid.uuid4())                                # shape of lift.py:328-331

Degrade contract, following xlp.py's precedent but sharpened: xlp.py logs and returns because
a missing report is tolerable; a missing IMPORT is not, so _lxml() raises and available()
lets the UI grey the menu item out up front. Module import itself never touches lxml, so
tests/test_import_smoke.py stays green on a lean box.

============================================================================
6. RUNNABLE XSLT — dekereke_transforms/dekereke2lift.xsl  (TESTED)
============================================================================
5 entries from 6 records on SampleLang_minimal.xml (bare UTF-8); 9 of 10 on
SampleLang_full.xml (UTF-16LE+BOM, ~40 cols). Empty error_log both times.

<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml" encoding="UTF-8" indent="yes"/>

  <!-- Column names are user-defined PER DATABASE: every one arrives as a param. -->
  <xsl:param name="col.form"  select="'Phonetic'"/>
  <xsl:param name="col.gloss" select="'Gloss'"/>
  <xsl:param name="col.ps"    select="'Category'"/>
  <xsl:param name="col.ref"   select="'Reference'"/>
  <xsl:param name="col.audio" select="'SoundFile'"/>
  <xsl:param name="analang"   select="'qaa'"/>
  <xsl:param name="glosslang" select="'en'"/>
  <xsl:param name="audiolang" select="'qaa-Zxxx-x-audio'"/>
  <!-- Python supplies these two; XSLT 1.0 can make neither (see §2e). -->
  <xsl:param name="now"    select="'1970-01-01T00:00:00Z'"/>
  <xsl:param name="idfile" select="''"/>
  <xsl:variable name="guids" select="document($idfile)/guids"/>

  <xsl:template match="/phon_data">
    <lift version="0.13" producer="A-Z+T (Dekereke import)">
      <!-- rule 7: records with an empty phonetic form are skipped, not imported empty -->
      <xsl:apply-templates select="data_form[
              normalize-space(*[name()=$col.form]) != '']"/>
    </lift>
  </xsl:template>

  <xsl:template match="data_form">
    <xsl:variable name="pos"   select="position()"/>   <!-- position in the FILTERED list -->
    <xsl:variable name="form"  select="normalize-space(*[name()=$col.form])"/>
    <xsl:variable name="gloss" select="normalize-space(*[name()=$col.gloss])"/>
    <xsl:variable name="ps"    select="normalize-space(*[name()=$col.ps])"/>
    <xsl:variable name="ref"   select="normalize-space(*[name()=$col.ref])"/>
    <xsl:variable name="wav"   select="normalize-space(*[name()=$col.audio])"/>
    <xsl:variable name="guid">
      <xsl:choose>
        <xsl:when test="$guids/g[@n=$pos]"><xsl:value-of select="$guids/g[@n=$pos]/@entry"/></xsl:when>
        <xsl:otherwise><xsl:value-of select="concat('dk-',generate-id())"/></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="senseid">
      <xsl:choose>
        <xsl:when test="$guids/g[@n=$pos]"><xsl:value-of select="$guids/g[@n=$pos]/@sense"/></xsl:when>
        <xsl:otherwise><xsl:value-of select="concat('dk-s-',generate-id())"/></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <!-- shape and attribute set copied from io_put/lift.py:344-375 addentry() -->
    <entry dateCreated="{$now}" dateModified="{$now}" guid="{$guid}"
           id="{concat($form,'_',$guid)}">
      <lexical-unit/>                                  <!-- left empty: lift.py:351-353 -->
      <citation>
        <form lang="{$analang}"><text><xsl:value-of select="$form"/></text></form>
        <!-- audio is a sibling FORM, not <media href>: backend/langtags.py:43,
             io_put/lift.py:2881-2886. Bare filename; the folder is runtime state. -->
        <xsl:if test="$wav != ''">
          <form lang="{$audiolang}"><text><xsl:value-of select="$wav"/></text></form>
        </xsl:if>
      </citation>
      <!-- the join key for round-trip export. Keep it, or export can only regenerate. -->
      <xsl:if test="$ref != ''">
        <field type="dekereke-reference">
          <form lang="en"><text><xsl:value-of select="$ref"/></text></form>
        </field>
      </xsl:if>
      <sense id="{$senseid}">
        <xsl:if test="$ps != ''"><grammatical-info value="{$ps}"/></xsl:if>
        <definition>
          <form lang="{$glosslang}"><text><xsl:value-of select="$gloss"/></text></form>
        </definition>
        <gloss lang="{$glosslang}"><text><xsl:value-of select="$gloss"/></text></gloss>
      </sense>
    </entry>
  </xsl:template>
  <!-- qvp_acoustic_data_ and every unmapped column: no template matches them, so they
       never reach the output. No explicit suppression needed. -->
</xsl:stylesheet>

Driven from Python (this exact call ran):
    xsl=etree.XSLT(etree.parse('dekereke2lift.xsl'))
    src=etree.fromstring(open(path,'rb').read())              # BYTES
    res=xsl(src, **{'col.form':etree.XSLT.strparam('Phonetic'),
                    'col.gloss':etree.XSLT.strparam('IndonesianGloss'),
                    'col.ps':etree.XSLT.strparam('Category'),
                    'col.audio':etree.XSLT.strparam('SoundFile'),
                    'analang':etree.XSLT.strparam('iau'),
                    'glosslang':etree.XSLT.strparam('id'),
                    'audiolang':etree.XSLT.strparam('iau-Zxxx-x-audio'),
                    'now':etree.XSLT.strparam(_now()),
                    'idfile':etree.XSLT.strparam(idpath.as_uri())})
Actual output, first entry:
    <entry dateCreated="2026-09-02T00:00:00Z" dateModified="2026-09-02T00:00:00Z"
           guid="dbf813a5-c643-47f1-a4b9-f48b14abc3b4" id="oudo_dbf813a5-c643-47f1-a4b9-f48b14abc3b4">
      <lexical-unit/>
      <citation><form lang="iau"><text>oudo</text></form>
                <form lang="iau-Zxxx-x-audio"><text>0012_turun.wav</text></form></citation>
      <field type="dekereke-reference"><form lang="en"><text>0012</text></form></field>
      <sense id="6f84486f-a09e-4682-bf6a-a84875c93d7d"><grammatical-info value="Verb"/>
        <definition><form lang="id"><text>turun</text></form></definition>
        <gloss lang="id"><text>turun</text></gloss></sense>
    </entry>

CAUTION on $pos: position() inside the template is the position in the FILTERED node list.
The ids document must therefore be indexed 1..N_kept, not 1..N_records, or the last entries
fall through to generate-id(). Safer alternative, if you want it: key the ids document by
Reference instead of position (<g ref="0012" entry="..." sense="..."/>) and look up with
$guids/g[@ref=$ref] — immune to filtering and to record reordering.

============================================================================
7. RUNNABLE XSLT — dekereke_transforms/lift2dekereke_merge.xsl  (TESTED, PRIMARY)
============================================================================
Primary input is the ORIGINAL Dekereke file, so record order, unmapped columns,
qvp_acoustic_data_ blocks and source indentation all survive untouched.
Shown with the §2f key() optimisation and the §"blanking trap" guard both applied.

<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <!-- UTF-8 = current Dekereke release. Driver overrides to UTF-16 on an old database;
       libxslt then emits UTF-16LE **with BOM** (measured). -->
  <xsl:output method="xml" encoding="UTF-8" indent="no"/>

  <xsl:param name="liftfile" select="''"/>
  <xsl:param name="mapfile"  select="''"/>
  <xsl:param name="analang"  select="'qaa'"/>
  <xsl:param name="col.ref"  select="'Reference'"/>
  <xsl:variable name="lift" select="document($liftfile)/lift"/>
  <xsl:variable name="map"  select="document($mapfile)/mapping"/>

  <!-- 187x faster than a predicate at N=3000 (11.22s -> 0.06s). key() indexes the
       CURRENT document only, hence the for-each context switch at each use site. -->
  <xsl:key name="byref" match="entry"
           use="field[@type='dekereke-reference']/form/text"/>

  <xsl:template match="@*|node()">
    <xsl:copy><xsl:apply-templates select="@*|node()"/></xsl:copy>
  </xsl:template>

  <xsl:template match="data_form/*">
    <xsl:variable name="name" select="name()"/>
    <xsl:variable name="role" select="$map/col[@name=$name]/@role"/>
    <xsl:variable name="ref"  select="normalize-space(../*[name()=$col.ref])"/>
    <!-- GUARD: an entry deleted in A-Z+T yields an empty node-set, and an unguarded
         value-of would BLANK the original Dekereke value (measured: 'tei' -> ''). -->
    <xsl:variable name="hit">
      <xsl:for-each select="$lift">
        <xsl:value-of select="count(key('byref',$ref))"/>
      </xsl:for-each>
    </xsl:variable>
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:choose>
        <xsl:when test="$ref!='' and $hit!='0' and $role='form'">
          <xsl:for-each select="$lift">
            <xsl:value-of select="key('byref',$ref)/citation/form[@lang=$analang]/text"/>
          </xsl:for-each>
        </xsl:when>
        <xsl:when test="$ref!='' and $hit!='0' and $role='tone'">
          <xsl:for-each select="$lift">
            <xsl:value-of select="key('byref',$ref)/sense/field[@type='tone']/form/text"/>
          </xsl:for-each>
        </xsl:when>
        <xsl:when test="$ref!='' and $hit!='0' and $role='audio'">
          <xsl:for-each select="$lift">
            <xsl:value-of select="key('byref',$ref)/citation/form[
                                    @lang=concat($analang,'-Zxxx-x-audio')]/text"/>
          </xsl:for-each>
        </xsl:when>
        <!-- everything else — unmapped columns, unmatched refs — copied verbatim -->
        <xsl:otherwise><xsl:apply-templates select="node()"/></xsl:otherwise>
      </xsl:choose>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>

Measured behaviour, LIFT edited to change 0018 sika->siga and add tone groups:
    <Phonetic>siga</Phonetic>          <- written from A-Z+T
    <Speaker2>LH</Speaker2>            <- tone group written into the mapped column
    <Tulisan>sika</Tulisan>            <- UNMAPPED, preserved verbatim
    <Catatan>ejaan belum pasti: sika / siga</Catatan>   <- UNMAPPED, preserved
    <Xstraight>tei dobe</Xstraight>    <- UNMAPPED, preserved
  and the record skipped on import (0027, empty Phonetic, <kosong>x</kosong>) came through
  completely intact — which the regenerate path cannot do at all.

The mapping document Python writes:
    <mapping>
      <col name="Reference"       role="ref"/>
      <col name="Category"        role="ps"/>
      <col name="SoundFile"       role="audio"/>
      <col name="IndonesianGloss" role="gloss"/>
      <col name="Phonetic"        role="form"/>
      <col name="Tulisan"         role=""/>       <!-- unmapped: preserved on merge -->
      <col name="Speaker2"        role="tone"/>
      ...
    </mapping>
For 'fresh' mode this same document drives <xsl:element name="{@name}"> in
lift2dekereke.xsl; for 'merge' mode it is a role lookup table. One artifact, two uses.

============================================================================
8. VERDICT — is XSLT the right tool for BOTH directions?
============================================================================
YES for both, with one condition and four carve-outs. Kent's instinct is right, and it is
better than it looks on paper, because the two things that seemed to disqualify XSLT 1.0 —
per-database column names and three input encodings — turned out to cost nothing:
*[name()=$col] handles the first, and the second never reaches the stylesheet.

IMPORT (Dekereke -> LIFT): XSLT wins clearly. The stylesheet IS the mapping — a reviewer,
including Kent, can read it and see exactly which Dekereke column becomes which LIFT
element, which is not true of 200 lines of ElementTree calls. Filtering empty-phonetic
records is one predicate. Dropping qvp_acoustic_data_ costs zero lines (nothing matches it).
It also sidesteps a real bug: bulk-building via addentry() in a loop would hit
io_put/lift.py:328-331 `allguids[0]` -> IndexError on the empty LIFT a fresh import starts from.
The only thing Python must inject is GUIDs + timestamps, via document($idfile) — an
eight-line side file, not an architecture.

EXPORT (LIFT -> Dekereke): XSLT wins even MORE clearly, but ONLY in merge mode. The identity
transform + role override is the single most XSLT-shaped part of this whole job — it is four
templates and it is loss-free, where the equivalent Python is a fiddly tree walk that has to
reimplement "copy everything except". Regeneration mode is the weak one and should be labelled
as such in the UI ("new Dekereke file — only mapped columns"), because it demonstrably blanks
Tulisan/Catatan/Xstraight. Ship merge first; regenerate is the fallback for projects that were
not imported from Dekereke.

So the honest framing is the inverse of the question's suggested split: it is not
"XSLT for export, Python for import" — it is XSLT for both, with Python owning a narrow,
well-defined perimeter:
  1. bytes in, bytes out (encoding on read; CRLF restoration on write)
  2. GUID + UTC-Z timestamp generation, handed over as a document
  3. XML-name validation of the column inventory before an export can raise XSLTApplyError
  4. the mapping-guess heuristics and the confirmation dialog

Where the plan at /Users/Seth/GIT/azt/planning/DEKEREKE_IO_PLAN.md needs amending:
  - §3 has to_lift() populating a LiftXML via addentry() per record. Replace with the bulk
    XSLT build + one parse of the result. Faster, avoids the makenewguid IndexError, and
    keeps the mapping readable.
  - §2.8 "CRLF line endings; preserve them on write" cannot be an XSLT obligation; move it
    to the driver as a byte fixup.
  - §3 export "Round-trip update ... keep the original column set and record order" should be
    stated as what it is: the ORIGINAL FILE is the transform input, not a reconstruction.
  - Add: store the source .xml path, its encoding, its had_crlf flag, and the confirmed
    mapping in settings/ at import time. Merge export is impossible without all four.

One non-negotiable prerequisite before any of this lands: file.gettransformsdir() is broken
(§1b) and the XLingPaper compile path it serves has never run. Either fix it in the same PR
(a two-line change to use pathname_from_base_dir, which incidentally revives Kent's own
XeLaTeX report compilation) or bypass it entirely for dekereke_transforms/. Do not copy it.

## Open questions
- Which Dekereke column carries the tone/pitch group A-Z+T produces? The samples have `_Pitch` twins (`CMPLalt_Pitch`, `INCMP_Pitch`) alongside verb-paradigm columns and a standalone `Pitch` in SampleLang_full.xml. If A-Z+T's per-sense tone group (io_put/lift.py:1069, `field[@type='tone']`) maps to `Pitch`, the mapping is 1:1; if it must fan out to the per-paradigm `X_Pitch` twins, the export stylesheet needs a role='tone' column set plus a rule for which LIFT pronunciation/trait[@name='location'] value feeds which twin. Not answerable from the samples alone — needs a real Fayu database or Rod Casali.
- Does A-Z+T's LIFT ever carry a namespace? Every path above assumes LIFT 0.13's no-namespace form, which is what io_put/lift.py's findall() strings assume too (e.g. `field[@type='tone']/form/text`). If a FLEx export ever arrives namespaced, every XPath in both stylesheets silently matches nothing. Worth one defensive assertion in the driver rather than a namespace-agnostic `*[local-name()=...]` rewrite of both stylesheets.
- Where should `field type="dekereke-reference"` live — sense-level or entry-level — and will Kent accept a custom field type at all? I put it on the entry, since the Dekereke record is an entry. io_put/lift.py:4554-4557 permits `field` under both entry and sense. If Kent objects to a custom type, the fallback join key is the entry `@id` (which encodes the form), but that breaks the moment a transcription is corrected — exactly the edit the round-trip exists to carry.
- Should the merge export write back a form A-Z+T CHANGED, or only fields A-Z+T ADDED? The tested merge overwrites `Phonetic` from the LIFT citation, which is right if A-Z+T is the transcription authority and wrong if Dekereke is. This is a policy question for Seth, and it should probably be a per-column checkbox in the same mapping dialog rather than a hard-coded role.
- Does any real Dekereke database in the field have a column name that is not a valid XML QName? It cannot — Dekereke writes those names as element names, so the file would not parse. So the §2a validation is really a guard against a mapping document Python builds wrongly, not against user data. Worth confirming that Dekereke itself rejects such column names at entry, in which case the validation can be an assert rather than a user-facing error.
- Performance ceiling not measured: the keyed merge was benchmarked at N=3000 records against a synthetic LIFT. A real A-Z+T LIFT with full pronunciation/example/field subtrees at 16 MB (io_put/lift.py:1245-1250) will build a larger key index. Should be re-measured on Seth's actual Fayu database before claiming the merge is instant.