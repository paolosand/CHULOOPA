% LaTeX2e document class for submissions to the
% Conference on AI Music Creativity (AIMC):
%
% - uses more LaTeX conventions
% - line numbers at submission time replaced with aligned numbers from
%   lineno package
% - automatically loads times package for authors
% - loads natbib automatically; this can be suppressed with the
%   [nonatbib] package option
% - adds foot line to first page identifying the conference
% - adds submission option for submission to e.g. arXiv
%
% Simplified version of and adapted from the NeurIPS LaTeX2e packages by
% Roman Garnett (garnett@wustl.edu) and the many authors of
% nips15submit_e.sty, including MK and drstrip@sandia
%
% License: LaTeX Project Public License 1.3c
% last revision: Jan 2026

\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{aimc2026}[2026/01/21 AIMC 2026 document class]

% Option handling
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{article}}
\ProcessOptions\relax

% Load base class
\LoadClass{article}

% fonts
\renewcommand{\rmdefault}{ptm}
\renewcommand{\sfdefault}{phv}

% change this every year for notice string at bottom
\newcommand{\@aimcordinal}{7\textsuperscript{th}}
\newcommand{\@aimcyear}{2026}
\newcommand{\@aimcdates}{September 16\textsuperscript{th}-18\textsuperscript{th}}
\newcommand{\@aimclocation}{Berlin, Germany}

\newcommand{\@noticestring}{%
  Proceedings of the \@aimcordinal\/ Conference on AI Music Creativity
  (AIMC \@aimcyear),
  \@aimclocation, \@aimcdates%
}


% load natbib
\RequirePackage[round,authoryear]{natbib}

% header/footer styling
\RequirePackage{fancyhdr}

% set page geometry
\RequirePackage[verbose=true,a4paper]{geometry}
\AtBeginDocument{
  \newgeometry{
    left=2cm,
    right=2cm,
    top=2cm,
    bottom=2cm,
    headheight=12pt,
    headsep=25pt,
    footskip=30pt
  }
  \@ifpackageloaded{fullpage}
    {\ClassWarning{aimc2026}{fullpage package not allowed! Overwriting formatting.}}
    {}
}

\setlength{\columnsep}{8mm}

\widowpenalty=10000
\clubpenalty=10000
\flushbottom
\sloppy

% font sizes with reduced leading
\renewcommand{\normalsize}{%
  \@setfontsize\normalsize\@xpt\@xipt
  \abovedisplayskip      7\p@ \@plus 2\p@ \@minus 5\p@
  \abovedisplayshortskip \z@ \@plus 3\p@
  \belowdisplayskip      \abovedisplayskip
  \belowdisplayshortskip 4\p@ \@plus 3\p@ \@minus 3\p@
}
\normalsize
\renewcommand{\small}{%
  \@setfontsize\small\@ixpt\@xpt
  \abovedisplayskip      6\p@ \@plus 1.5\p@ \@minus 4\p@
  \abovedisplayshortskip \z@  \@plus 2\p@
  \belowdisplayskip      \abovedisplayskip
  \belowdisplayshortskip 3\p@ \@plus 2\p@   \@minus 2\p@
}
\renewcommand{\footnotesize}{\@setfontsize\footnotesize\@ixpt\@xpt}
\renewcommand{\scriptsize}{\@setfontsize\scriptsize\@viipt\@viiipt}
\renewcommand{\tiny}{\@setfontsize\tiny\@vipt\@viipt}
\renewcommand{\large}{\@setfontsize\large\@xiipt{14}}
\renewcommand{\Large}{\@setfontsize\Large\@xivpt{16}}
\renewcommand{\LARGE}{\@setfontsize\LARGE\@xviipt{20}}
\renewcommand{\huge}{\@setfontsize\huge\@xxpt{23}}
\renewcommand{\Huge}{\@setfontsize\Huge\@xxvpt{28}}

% sections with less space
\providecommand{\section}{}
\renewcommand{\section}{%
  \@startsection{section}{1}{\z@}%
                {-2ex \@plus -0.5ex \@minus -0.2ex}%
                { 0.1ex \@plus  0.2ex \@minus  0.2ex}%
                {\normalsize\bf\raggedright\MakeUppercase}%
}
\providecommand{\subsection}{}
\renewcommand{\subsection}{%
  \@startsection{subsection}{2}{\z@}%
                {-1.2ex \@plus -0.5ex \@minus -0.2ex}%   % 1.8em above, rubber
                { 0.1ex \@plus  0.2ex \@minus 0.2ex}%
                {\normalsize\bf\raggedright}%
}
\providecommand{\subsubsection}{}
\renewcommand{\subsubsection}{%
  \@startsection{subsubsection}{3}{\z@}%
                {-1.2ex \@plus -0.5ex \@minus -0.2ex}%   % 1.5em above, rubber
                { 0.1ex \@plus  0.1ex}%
                {\normalsize\raggedright}%
}

\providecommand{\subsubsubsection}{}
\renewcommand{\subsubsubsection}{%
  \vskip5pt{\noindent\normalsize\rm\raggedright}%
}

% float placement
\renewcommand{\topfraction      }{0.85}
\renewcommand{\bottomfraction   }{0.4}
\renewcommand{\textfraction     }{0.1}
\renewcommand{\floatpagefraction}{0.7}

\newlength{\@aimcabovecaptionskip}\setlength{\@aimcabovecaptionskip}{7\p@}
\newlength{\@aimcbelowcaptionskip}\setlength{\@aimcbelowcaptionskip}{\z@}

\setlength{\abovecaptionskip}{\@aimcabovecaptionskip}
\setlength{\belowcaptionskip}{\@aimcbelowcaptionskip}

% swap above/belowcaptionskip lengths for tables
\renewenvironment{table}
  {\setlength{\abovecaptionskip}{\@aimcbelowcaptionskip}%
   \setlength{\belowcaptionskip}{\@aimcabovecaptionskip}%
   \@float{table}}
  {\end@float}

% footnote formatting
\setlength{\footnotesep }{6.65\p@}
\setlength{\skip\footins}{9\p@ \@plus 4\p@ \@minus 2\p@}
\renewcommand{\footnoterule}{\kern-3\p@ \hrule width 12pc \kern 2.6\p@}
\setcounter{footnote}{0}

% paragraph formatting
\setlength{\parindent}{\z@}
\setlength{\parskip  }{5.5\p@}

% list formatting
\setlength{\topsep       }{4\p@ \@plus 1\p@   \@minus 2\p@}
\setlength{\partopsep    }{1\p@ \@plus 0.5\p@ \@minus 0.5\p@}
\setlength{\itemsep      }{2\p@ \@plus 1\p@   \@minus 0.5\p@}
\setlength{\parsep       }{2\p@ \@plus 1\p@   \@minus 0.5\p@}
\setlength{\leftmargin   }{1.5em}
\setlength{\leftmargini  }{\leftmargin}
\setlength{\leftmarginii }{1.5em}
\setlength{\leftmarginiii}{1.5em}
\setlength{\leftmarginiv }{1.0em}
\setlength{\leftmarginv  }{0.5em}
\def\@listi  {\leftmargin\leftmargini}
\def\@listii {\leftmargin\leftmarginii
              \labelwidth\leftmarginii
              \advance\labelwidth-\labelsep
              \topsep  2\p@ \@plus 1\p@    \@minus 0.5\p@
              \parsep  1\p@ \@plus 0.5\p@ \@minus 0.5\p@
              \itemsep \parsep}
\def\@listiii{\leftmargin\leftmarginiii
              \labelwidth\leftmarginiii
              \advance\labelwidth-\labelsep
              \topsep    1\p@ \@plus 0.5\p@ \@minus 0.5\p@
              \parsep    \z@
              \partopsep 0.5\p@ \@plus 0\p@ \@minus 0.5\p@
              \itemsep \topsep}
\def\@listiv {\leftmargin\leftmarginiv
              \labelwidth\leftmarginiv
              \advance\labelwidth-\labelsep}
\def\@listv  {\leftmargin\leftmarginv
              \labelwidth\leftmarginv
              \advance\labelwidth-\labelsep}
\def\@listvi {\leftmargin\leftmarginvi
              \labelwidth\leftmarginvi
              \advance\labelwidth-\labelsep}

% create title - save thanks text for output after twocolumn spanning
\newtoks\@aimcthanks
\global\@aimcthanks={}
\let\@oldthanks\thanks
\renewcommand{\thanks}[1]{%
  \footnotemark
  \protected@xdef\@aimcthanks{\the\@aimcthanks\protect\footnotetext[\the\c@footnote]{#1}}%
}
\providecommand{\maketitle}{}
\renewcommand{\maketitle}{%
  \par
  \begingroup
    \renewcommand{\thefootnote}{\fnsymbol{footnote}}
    % for perfect author name centering
    \renewcommand{\@makefnmark}{\hbox to \z@{$^{\@thefnmark}$\hss}}
    \@maketitle
  \endgroup
  \let\maketitle\relax
}
% Output saved thanks footnotes
\newcommand{\@outputthanks}{%
  \begingroup
    \renewcommand{\thefootnote}{\fnsymbol{footnote}}%
    \@aimcthanks
    \global\let\@aimcthanks\@empty
  \endgroup
  \setcounter{footnote}{0}%
}


% create title
\providecommand{\@maketitle}{}
\renewcommand{\@maketitle}{%
  \vbox{%
    \hsize\textwidth
    \linewidth\hsize
    \vskip 0.1in
    \centering
    {\LARGE\bf \@title\par}
      \def\And{%
        \end{tabular}\hfil\linebreak[0]\hfil%
        \begin{tabular}[t]{c}\bf\rule{\z@}{24\p@}\ignorespaces%
      }
      \def\AND{%
        \end{tabular}\hfil\linebreak[4]\hfil%
        \begin{tabular}[t]{c}\bf\rule{\z@}{24\p@}\ignorespaces%
      }
      \begin{tabular}[t]{c}\bf\rule{\z@}{24\p@}\@author\end{tabular}%
    \vskip 22\p@
  }
}

% add conference notice to header of first page
\fancypagestyle{firstpage}{%
  \fancyhf{}%
  \renewcommand{\headrulewidth}{0pt}%
  \fancyhead[C]{\footnotesize\@noticestring}%
  \fancyfoot[C]{\thepage}%
}
\newcommand{\aimcnotice}{%
  \thispagestyle{firstpage}%
  \@outputthanks
}

% abstract styling
\renewenvironment{abstract}%
{%
  \centerline{\large\bf Abstract}%
  \vspace{0.5ex}%
  \list{}{\leftmargin=1.5cm \rightmargin=1.5cm}%
\item\relax
}
{%
  \endlist
  \vskip 0.3in%
}

\endinput
