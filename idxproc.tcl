#! /usr/bin/env tclsh

fconfigure stdin -encoding koi8-r
fconfigure stdout -encoding koi8-r

# Перевод строки в сортировочный ключ: материал для string map

# Особым образом обрабатываются значки \mapsto и греческие буквы --
# должны попасть в конец спецзнаков
set stripRl {\\mapsto ?? \\lambda ??l \\pi ??p \\sum ??s \\Theta ??t}

# Всякие "мусорные" знаки выкидываем
set stripCh  "`'~\\\{\}\@\$\"\#<"
for {set i 0} {$i < [string length $stripCh]} {incr i} {
    lappend stripRl [string index $stripCh $i] {}
}

#puts $stripRl
#  Процедура перевода строки в ключ для сортировки
proc strip {str} {
    global stripRl

    return [string map $stripRl $str]
} 

# Присвоить списку переменных значения из списка значений
proc mvset {vars vals} {
    if {[llength $vars] != [llength $vals]} {
	error "mvset: different lengths for vars and vals"
    }
    foreach var $vars val $vals {
	upvar $var vv
	set vv $val
    }
    return
}

## Заменяем TeX-овские коды на нормальные русские буквы.
set itxt {}
while {![eof stdin]} {
    append itxt [read stdin]
}

set fromList {CYRA 	CYRB 	CYRV 	CYRG 	CYRD 	CYRE 	CYRZH   CYRZ  \
	      CYRI 	CYRISHRT CYRK	CYRL	CYRM	CYRN	CYRO    CYRP  \
	      CYRR	CYRS	CYRT	CYRU	CYRF	CYRH	CYRC    CYRCH \
	      CYRSH	CYRSHCH	CYRHRDSN CYRERY CYRSFTSN CYREREV CYRYU  CYRYA \
              cyra 	cyrb 	cyrv 	cyrg 	cyrd 	cyre 	cyrzh   cyrz  \
	      cyri	cyrishrt cyrk	cyrl	cyrm	cyrn	cyro    cyrp  \
	      cyrr	cyrs	cyrt	cyru	cyrf	cyrh	cyrc    cyrch \
	      cyrsh	cyrshch cyrhrdsn cyrery cyrsftsn cyrerev cyryu  cyrya}

# Поскольку скрипт читается в неправильной кодировке, приходится задавать
# русские символы уникодными кодами
set toList   {\u410    	\u411 	\u412 	\u413 	\u414 	\u415	\u416   \u417  \
	      \u418	\u419 	\u41a	\u41b 	\u41c 	\u41d   \u41e   \u41f  \
	      \u420 	\u421 	\u422 	\u423 	\u424	\u425 	\u426   \u427  \
	      \u428 	\u429 	\42a 	\u42b 	\u42c 	\u42d 	\u42e   \u42f  \
	      \u430 	\u431 	\u432 	\u433 	\u434 	\u435 	\u436   \u437  \
	      \u438 	\u439 	\u43a 	\u43b 	\u43c 	\u43d 	\u43e   \u43f  \
	      \u440 	\u441 	\u442 	\u443 	\u444 	\u445 	\u446   \u447  \
	      \u448 	\u449 	\u44a 	\u44b	\u44c 	\u44d 	\u44e   \u44f}

set rl {}
foreach from $fromList to $toList {
    lappend rl "\\IeC {\\$from }" $to
}

# Вроде бы, нет никакой нужды защищать пробелы бэкслэшами
lappend rl {\ } { }
# Какая-то ерунда с cимволами ->, в названиях процедур.
lappend rl {\unhbox \voidb@x \kern \z@ \char `\discretionary {-}{}{}} -
lappend rl {\unhbox \voidb@x \kern \z@ \char `\mskip \medmuskip } ">"
lappend rl {\unhbox \voidb@x \kern \z@ \char `\, } {,}
set itxt [string map $rl $itxt]

set ilist [split $itxt \n]
# Забыть старое значение -- больно большое
unset itxt

# Такой map
set ilist2 {}
foreach itm $ilist {
    if {[string equal $itm ""]} {
	continue
    }
    if {![regexp {\\indexentry{(.*)}{(.*)}} $itm junk body pno]} {
	puts "Bad line: $itm"
	continue
    }
    set bsplit [split $body |]
    if {[llength $bsplit] != 6} {
	puts "Wrong number of fields: $body [llength $bsplit]"
	continue
    }
    set bsp {}
    foreach b $bsplit {
	regsub -all {[ \t]+} $b " " b
	set b [string trim $b]
	lappend bsp $b
    }
    lappend bsp $pno
    lappend ilist2 $bsp
    #puts $bsplit
}
unset ilist

# Теперь делаем ключ для сортировки.
set ilist3 {}
foreach itm $ilist2 {
    # В качестве разделителя два пробела, чтобы первичные входы 
    # с одним пробелом на этом месте при сортировке оказывались дальше.
    set skey "[strip [lindex $itm 0]]  [strip [lindex $itm 1]]"
    lappend ilist3 [list $skey $itm]
    #puts [list $skey $itm]
}
unset ilist2

set ilist4 [lsort -dictionary -index 0 $ilist3]
unset ilist3

##
#foreach itm $ilist4 {
#    puts $itm
#}
#exit

# Теперь приводим к полуфабрикатно-печатному виду:
# primary secondary origprim origsec pno
set ilist5 {}
foreach itm $ilist4 {
    # Первым элементом списка -- ключ для сортировки, из него потребуется только первая буква.
    set firstlet [string tolower [string index [lindex $itm 0] 0]]
    set itmb [lindex $itm 1]
    # Разбираем поля основной части
    mvset {primary secondary origprim origsec flags pnoadd pno} $itmb

    # Если во флагах p -- в primary имя процедуры, надо сменить шрифт.
    if {-1 != [string first p $flags]} {
	# Особым случаем оказывается символ ","
	if [string equal "," [string index $primary 0]] {
	    set primary "\\texttt{,}[string range $primary 1 end]"
	} elseif {[regexp {^(.*?)([ ,].*)$} $primary junk pname rest]} {
	    set primary "\\texttt{$pname}$rest"
	} else {
	    set primary "\\texttt{$primary}"
	}
    }

    # Если во флагах d -- это определение процедуры, номер страницы
    # идет курсивом.
    if {-1 != [string first d $flags]} {
	set pno "{\\it $pno}"
    }

    # Если добавка "п" -- она идет курсивом, иначе через пробел.
    # Здесь тоже приходится обозначать букву уникодным номером
    if [string equal \u43f $pnoadd] {
	set pno "$pno{\\it \u43f}"
    } elseif {![string equal "" $pnoadd]} {
	set pno "$pno $pnoadd"
    }
    
    lappend ilist5 [list $firstlet $primary $secondary $origprim $origsec $pno]
}
unset ilist4

# Склеиваем одинаковые строки
set ilist6 {}
for {set i 0} {$i < [llength $ilist5]} {incr i} {
    set itm [lindex $ilist5 $i]
    mvset {firstlet primary secondary origprim origsec pno} $itm

    set lastpno $pno
    
    for {set j [expr $i+1]} {$j < [llength $ilist5]} {incr j} {
	set itmj [lindex $ilist5 $j]
	mvset {flj primj secj opj osj pnoj} $itmj

	if {![string equal $primary $primj]	\
		|| ![string equal $secondary $secj]} {
	    break
	}

	if {![string equal $lastpno $pnoj]} {
	    set pno "$pno, $pnoj"
	}
	set lastpno $pnoj

	if {[string equal "" $origsec] \
		&& ![string equal "" $osj]} {
	    set origsec $osj
	}
    }

    # Устанавливаем i в последнюю из склеенных строчек.
    set i [expr $j-1]
    lappend ilist6 [list $firstlet $primary $secondary $origprim $origsec $pno]
}
unset ilist5

# К сожалению, отдельным проходом приходится искать среди всех 
# входов с данным primary непустой origprim
set ilist7 {}
for {set i 0} {$i < [llength $ilist6]} {incr i} {
    set itm [lindex $ilist6 $i]
    mvset {firstlet primary secondary origprim origsec pno} $itm

    # secl -- непервые записи с данным primary
    set secl {}
    for {set j [expr $i+1]} {$j < [llength $ilist6]} {incr j} {
	set itmj [lindex $ilist6 $j]
	mvset {flj primj secj opj osj pnoj} $itmj

	if {![string equal $primary $primj]} {
	    break
	}

	if {[string equal "" $origprim] \
		&& ![string equal "" $opj]} {
	    set origprim $opj
	}

	lappend secl [list $flj $primj $secj $opj $osj $pnoj]
    }

    # Устанавливаем i в последнюю из склеенных строчек.
    set i [expr $j-1]
    # Добавляем к списку-результату первую запись
    lappend ilist7 [list $firstlet $primary $secondary $origprim $origsec $pno]
    # И остальные
    #!! как эффективнее?
    #set ilist7 [concat $ilist7 $secl]
    foreach itm $secl {
	lappend ilist7 $itm
    }
}
unset ilist6

# Наконец, генерим вывод
puts "\\begin{theindex}"
set prevfirstlet ""
set prevprim ""
foreach itm $ilist7 {
    mvset {firstlet primary secondary origprim origsec pno} $itm

    if {[string is alpha $firstlet] \
	    && ![string equal $firstlet $prevfirstlet] } {
	puts "\\bigskip"
    }

    if {![string equal "" $origprim]} {
	set fullprim "$primary \[$origprim\]"
    } else {
	set fullprim $primary
    }

    if {![string equal "" $origsec]} {
	set fullsec "$secondary \[$origsec\]"
    } else {
	set fullsec $secondary
    }

    if [string equal "" $secondary] {
	puts "\\item {$fullprim} $pno"
    } else {
	if {![string equal $primary $prevprim]} {
	    puts "\\item {$fullprim}"
	}
	puts "  \\subitem {$fullsec} $pno"
    }

    set prevprim $primary
    set prevfirstlet $firstlet
}
puts "\\end{theindex}"

#foreach itm $ilist6 {
#    puts $itm
#}
