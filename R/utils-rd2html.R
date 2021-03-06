#' Knit package documentation
#'
#' Run examples in a package and insert output into the examples code;
#' \code{knit_rd_all()} is a wrapper around \code{knit_rd()} to build static
#' HTML help pages for all packages under the \file{html} directory of them.
#' @param pkg package name
#' @param links a charactor vector of links to be passed to
#'   \code{\link[tools]{Rd2HTML}}
#' @param frame whether to put a navigation frame on left of the index page
#' @return All HTML pages corresponding to topics in the package are written
#'   under the current working directory. An \file{index.html} is also written
#'   as a table of content.
#' @note Ideally the html pages should be put under the \file{html} directory of
#'   an installed package which can be found via \code{system.file('html',
#'   package = 'your_package_name')}, otherwise some links may not work (e.g.
#'   the link to the DESCRITION file).
#' @examples \dontrun{knit_rd('maps')
#' knit_rd('rpart')
#' setwd(system.file('html', package = 'ggplot2'))
#' knit_rd('ggplot2') # time-consuming!
#'
#' knit_rd_all()  # this may take really long time if you have many packages installed
#' }
#' @export
knit_rd = function(pkg, links = tools::findHTMLlinks(), frame = TRUE) {
  library(pkg, character.only = TRUE)
  optc = opts_chunk$get(); on.exit(opts_chunk$set(optc))
  file.copy(system.file('misc', c('highlight.css', 'highlight.pack.js', 'R.css'), package = 'knitr'), './')
  pkgRdDB = tools:::fetchRdDB(file.path(find.package(pkg), 'help', pkg))
  force(links); topics = names(pkgRdDB)
  for (p in topics) {
    message('** knitting documentation of ', p)
    tools::Rd2HTML(pkgRdDB[[p]], f <- tempfile(),
            package = pkg, Links = links, no_links = is.null(links), stages = 'render')
    txt = readLines(f, warn = FALSE)
    if (length(i <- grep('<h3>Examples</h3>', txt)) == 1L &&
      length(grep('</pre>', txt[i:length(txt)]))) {
      i0 = grep('<pre>', txt); i0 = i0[i0 > i][1L] - 1L
      i1 = grep('</pre>', txt); i1 = i1[i1 > i0][1L] + 1L
      tools::Rd2ex(pkgRdDB[[p]], ef <- tempfile())
      ex = readLines(ef, warn = FALSE)
      ex = ex[-(1L:grep('### ** Examples', ex, fixed = TRUE))]
      ex = c('```{r}', ex, '```')
      opts_chunk$set(fig.path = str_c('figure/', p, '-'), tidy = FALSE)
      res = try(knit2html(text = ex, envir = parent.frame(2), fragment.only = TRUE))
      if (inherits(res, 'try-error')) {
        res = ex; res[1] = '<pre><code class="r">'; res[length(res)] = '</code></pre>'
      }
      txt = c(txt[1:i0], res, txt[i1:length(txt)])
      txt = sub('</head>', '
<link rel="stylesheet" href="highlight.css">
<script src="highlight.pack.js"></script>
<script>hljs.initHighlightingOnLoad();</script>
</head>', txt)
    } else message('no examples found for ', p)
    writeLines(txt, str_c(p, '.html'))
  }
  unlink('figure/', recursive = TRUE)
  toc = sprintf('- <a href="%s" target="content">%s</a>', str_c(topics, '.html'), topics)
  toc = c(str_c('# ', pkg), '', toc, '',
          paste('Generated with [knitr](http://yihui.name/knitr) ', packageVersion('knitr')))
  markdown::markdownToHTML(text = paste(toc, collapse = '\n'), output = '00frame_toc.html',
                           title = str_c('R Documentation of ', pkg),
                           options = NULL, extensions = NULL, stylesheet = 'R.css')
  txt = readLines(file.path(find.package(pkg), 'html', '00Index.html'))
  unlink('00Index.html')
  # fix image links
  writeLines(gsub('../../../doc/html/', 'http://stat.ethz.ch/R-manual/R-devel/doc/html/',
                  txt, fixed = TRUE), '00Index.html')
  if (!frame) {
    unlink(c('00frame_toc.html', 'index.html'))
    # do not need a navigation frame, so make 00Index the real homepage
    (if (.Platform$OS.type == 'windows') file.copy else file.symlink)('00Index.html', 'index.html')
    return(invisible())
  }
  writeLines(sprintf(
'<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd">
<html>
<head><title>Documentation of the %s package</title></head>
<frameset cols="15%%,*">
  <frame src="00frame_toc.html">
  <frame src="00Index.html" name="content">
</frameset>
</html>
', pkg), 'index.html')
}

#' @rdname knit_rd
#' @export
knit_rd_all = function() {
  owd = getwd(); on.exit(setwd(owd))
  optk = opts_knit$get(); on.exit(opts_knit$set(optk))
  opts_knit$set(progress = FALSE)  # too much info to show
  links = tools::findHTMLlinks()
  for (p in .packages(TRUE)) {
    message('* Making static html help pages for ', p)
    setwd(system.file('html', package = p))
    knit_rd(p, links, frame = FALSE)
  }
}
