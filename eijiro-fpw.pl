#                                                         -*- Perl -*-
# eijiro-fpw - FreePWING script for EIJIRO
#
# !!! NOTICE !!!
# DO NOT CHANGE THE KANJI-CODE OF THIS SCRIPT. IT SHOULD BE SHIFT JIS.
#
# Copyright (C) 2000, Rei <rei@wdic.org>.
# This program is distributed in the hope that it will be useful, but
# without any warranty. See the GNU General Public License for the details.
#

use 5.005;
use strict;
use Getopt::Long;
use Jcode;
use FreePWING::FPWUtils::FPWParser;

my($fpwtext, $fpwheading, $fpwword2, $fpwkeyword, $fpwcopyright);
my $opt_charset;	# sjis, euc (eucjp, ujis), jis, iso_2022_jp or utf8.

my $sjis_any_re = qr/(?:[\x81-\x9f\xe0-\xfc][\x40-\x7e\x80-\xfc])/;
my $hiragana_re = qr/(?:\x82[\x9f-\xf1])/;	# [Çü-ÇÒ]
my $katakana_re = qr/(?:\x83[\x40-\x96])/;	# [É@-Éñ]

my %skip_word = (
	'a',	1,
	'an',	1,
	'and',	1,
	'at',	2,
	'by',	2,
	'for',	2,
	'in',	2,
	'on',	2,
	'or',	1,
	'the',	1,
	'to',	2
);


#-----------------------------------------------------------------------#
#	main routine							#
#-----------------------------------------------------------------------#

my $wc = 0;
my($current_word, $current_pos, $pos_index);
my($prev_word, $prev_pos) = ('', '');

#
# initialize this module.
#
&initialize();
initialize_fpwparser('text' => \$fpwtext,
		'heading' => \$fpwheading,
		'word2' => \$fpwword2,
		'keyword' => \$fpwkeyword,
		'copyright' => \$fpwcopyright);

#
# read the input files and write entries to the book.
#
while (defined(my $line = <>)) {
	$line =~ s/[\r\n]+$//;
	next if ($line eq '');

	if ($line !~ /^Å°(.+?) : (.+)$/) {
		&error("Unexpected line in $ARGV ($line)");
	}
	$current_word = $1;
	my $meaning = $2;

	#
	# extract POS from the word if any.
	#
	if ($current_word =~ s/\s*\{((?:$sjis_any_re|[0-9\-])+)\}//o) {
		$current_pos = $1;
		if ($current_pos =~ s/\-([0-9]+)$//) {
			if ($current_pos eq $prev_pos) {
				$pos_index++;
			} else {
				$pos_index = 1;
			}
		} else {
			$pos_index = 0;
		}
	} else {
		$pos_index = 0;
		$current_pos = '';
	}

	## FIXME: How to add "'" as a word?
	next if ($current_word =~ /^'*$/);

	if ($current_word eq $prev_word) {
		#
		# same word as previous, do not write heading or keyword.
		#
		if ('' ne $current_pos && $current_pos eq $prev_pos) {
			&write_pos_index($current_pos, $pos_index);
		} else {
			&write_pos($current_pos, $pos_index);
			$prev_pos = $current_pos;
		}
	} else {
		#
		# a new word is found. change to the new context and write the
		# heading and keyword.
		#
		$wc++;
		&new_entry($wc, $current_word);
		$prev_word = $current_word;
		$prev_pos = $current_pos;
		if ($meaning =~ /^Åy/) {
			&write_word_info($meaning);
			$fpwtext->add_indent_level(2);
			next;
		} else {
			$fpwtext->add_indent_level(2);
			if ('' ne $current_pos) {
				&write_pos($current_pos, $pos_index);
			}
		}
	}

	#
	# write the meanings of the current word.
	#
	write_meaning($meaning);
}

print "Total $wc entries were written.\n";
&write_copyright();

#
# clean up.
#
finalize_fpwparser('text' => \$fpwtext,
		'heading' => \$fpwheading,
		'word2' => \$fpwword2,
		'keyword' => \$fpwkeyword,
		'copyright' => \$fpwcopyright);
exit(0);


#-----------------------------------------------------------------------#
#	initialization														#
#-----------------------------------------------------------------------#
#
# void initialize();
# read the command line switches and initialize optional values.
#
sub initialize
{
	my $opt_usage;

	if (!GetOptions('help|h|?' => \$opt_usage,
			'charset|c:s' => \$opt_charset)
			|| scalar(@ARGV) < 1) {
		usage(1);
	}
	usage(0) if ($opt_usage);

	if (!defined($opt_charset) || '' eq $opt_charset) {
		my $lang = $ENV{'LC_ALL'} || $ENV{'LANG'};
		if ($lang =~ /ja_JP\.(\w+(-\w+)*)$/) {
			$opt_charset = $1;
		}
	}

	$opt_charset =~ tr/A-Z/a-z/;
	$opt_charset =~ s/-//g;
	if ('ujis' eq $opt_charset || 'eucjp' eq $opt_charset) {
		$opt_charset = 'euc';
	} elsif (!defined($opt_charset) || '' eq $opt_charset) {
		if ($ENV{'OS'} =~ /Windows/i
				|| $ENV{'COMSPEC'} =~ /COMMAND\.COM$/i
				|| $ENV{'COMSPEC'} =~ /CMD\.EXE$/i) {
			$opt_charset = 'sjis';
		} else {
			$opt_charset = 'euc';
		}
	} elsif ('sjis' ne $opt_charset
			&& 'euc' ne $opt_charset
			&& 'jis' ne $opt_charset
			&& 'iso_2022_jp' ne $opt_charset
			&& 'utf8' ne $opt_charset) {
		&error("$opt_charset: Unknown character set");
	}

	print "Detected display character set: $opt_charset\n";

	-f './copyright.txt' ||
		&error("A necessary file \'./copyright.txt\' not found.");
}


use constant MAXKEYWORDLEN => 128;

sub trim_keyword(\$) {
	my($ref) = @_;
	local $_ = $$ref;
	while (MAXKEYWORDLEN < length) {
		s/\s+\S*$// and next;
		$_ = substr($_, 0, MAXKEYWORDLEN);
		s/\A((?:[\x00-\x7F]+|(?:[\x8E\xA1-\xFE][\xA1-\xFE])+|(?:\x8F[\xA1-\xFE][\xA1-\xFE])+)*).+/$1/;	# remove broken bytes
		last;
	}
	$$ref = $_;
}


#-----------------------------------------------------------------------#
#	writing routines													#
#-----------------------------------------------------------------------#
#
# void new_entry(char *word);
# switch to the new entry and write the heading and keyword. this
# version does not support cross-reference, so the tag is not added.
#
sub new_entry
{
	my($index, $word) = @_;
	my($text_pos, $heading_pos);
	my(@key, @key2, $key, $key2);

	$word =~ s/\x81\x7c/\-/g;
	$word =~ s/__/_/g;
	$word =~ s/ÅF/: /g;

	&jprint("$index: $word\n");
	$word = Jcode::convert($word, 'euc', 'sjis');

	$fpwtext->new_entry() ||
		&error("Failed to add a new entry", $fpwtext);
	$fpwheading->new_entry() ||
		&error("Failed to add a new entry", $fpwheading);

	$text_pos = $fpwtext->entry_position();
	$heading_pos = $fpwheading->entry_position();

	#
	# heading.
	#
	$fpwheading->add_text($word) ||
		&error("Failed to add a heading", $fpwheading);

	#
	# search words - let them be found as far as possible...
	#
	@key = split(/; /, $word);

	foreach $key (@key) {
		if ($key =~ / \| /) {
			@key2 = split(/ \| /, $key);
			foreach $key (@key2) {
				$fpwword2->add_entry($key, $heading_pos, $text_pos) ||
					&error("Failed to add a search word ($key)", $fpwword2);
			}

		} else {
			trim_keyword($key);
			next if length($key) == 0;
			$fpwword2->add_entry($key, $heading_pos, $text_pos) ||
				&error("Failed to add a search word ($key)", $fpwword2);

			#
			# a little workaround for DDwin and Jamming.
			#
			if ($key =~ s/\s*[\"\$%\+_]\s*//g && $key !~ /^$/) {
				$fpwword2->add_entry($key, $heading_pos, $text_pos) ||
					&error("Failed to add a search word ($key)", $fpwword2);
			}
		}
	}

	#
	# also add each word as a keyword for 'jouken kensaku'. articles,
	# symbols and some other words may be skipped according to the word
	# count.
	#
	@key = ();
	@key2 = sort(split(/ +/, $word));
	$key2 = '';

	while (1) {
		$key = shift(@key2);
		last if (!defined($key) || '' eq $key);
		$key =~ s/^[\(\[\"]+//;
		$key =~ s/[\)\]\",\.:;!\?]+$//;
		$key =~ tr/A-Z/a-z/;

		next if ('' eq $key);
		if ($key ne $key2) {
			next if ((defined($skip_word{$key}) && 1 == $skip_word{$key})
					|| $key =~ /^[^a-zA-Z0-9]+$/);
			push(@key, $key);
			$key2 = $key;
		}
	}

	foreach $key (@key) {
		if (scalar(@key) <= 5 || !defined($skip_word{$key})) {
			trim_keyword($key);
			next if length($key) == 0;
			$fpwkeyword->add_entry($key, $heading_pos, $text_pos) ||
				&error("Failed to add keyword ($key)", $fpwkeyword);
		}
	}

	#
	# write the title to the body as a keyword.
	#
	@key = split(/; /, $word);
	$key = shift(@key);
	trim_keyword($key);

	if (length($key) > 0 &&
			(!$fpwtext->add_keyword_start()
			|| !$fpwtext->add_text($key)
			|| !$fpwtext->add_keyword_end())) {
		&error("Failed to add a keyword ($key)", $fpwtext);
	}

	foreach $key (@key) {
		trim_keyword($key);
		next if length($key) == 0;
		if (!$fpwtext->add_text('; ')
				|| !$fpwtext->add_keyword_start()
				|| !$fpwtext->add_text($key)
				|| !$fpwtext->add_keyword_end()) {
			&error("Failed to add a keyword ($key)", $fpwtext);
		}
	}

	$fpwtext->add_newline() || &error("Failed to add a newline", $fpwtext);
}

#
# void write_word_info(char *line);
# write the line that contains such information like the pronounce etc.
#
sub write_word_info
{
	my($info) = @_;

	$info =~ s/ÅyÅóÅz(?:$katakana_re|\x81[\x41\x5b])*//o;
	$info =~ s/ÅyÉåÉxÉãÅz[0-9]*(?:ÅA)*//;
	$info =~ s/ÅyëÂäwì¸ééÅz(?:ÅA)*//;
	$info =~ s/ÅAÅy/ Åy/g;
	$info =~ s/ÅA//g;

	if ($info !~ /^$/) {
		if (!$fpwtext->add_text(Jcode::convert($info, 'euc', 'sjis'))
				|| !$fpwtext->add_newline()) {
			&error("Failed to add text ($info)", $fpwtext);
		}
	}
}

#
# void write_pos(char *pos, int index);
#
sub write_pos
{
	my($pos, $index) = @_;

	if ('' ne $pos) {
		$fpwtext->add_text('[' . Jcode::convert($pos, 'euc', 'sjis') . ']') ||
			&error("Failed to write POS [$pos]", $fpwtext);
	}
	if (0 < $index) {
		if (!$fpwtext->add_newline() || !$fpwtext->add_text("$index\. ")) {
			&error("Failed to write [$pos] index $index", $fpwtext);
		}
	} else {
		$fpwtext->add_text(' ') ||
			&error("Failed to write a white space", $fpwtext);
	}
}

#
# void write_pos_index(char *pos, int index);
#
sub write_pos_index
{
	my($pos, $index) = @_;

	$fpwtext->add_text("$index\. ") ||
		&error("Failed to write [$pos] index $index", $fpwtext);
}

#
# void write_meaning(char *line)
# write the meaning(s) of the current word.
#
sub write_meaning
{
	my(@list, $char, $next, $mean, $yorei);

	$mean = shift(@_);
	$mean =~ s/\x81\x6f(?:$hiragana_re|\x81[\x5e\x69\x6a]| )+\x81\x70//go;

	@list = unpack('C*', $mean);
	$mean = '';

	while (1) {
		$char = shift(@list);
		last if (!defined($char) || !$char);
		if (0x81 == $char) {
			$next = shift(@list);
			if (0x41 == $next || 0x43 == $next) {		# ÅAÅC
				$mean .= ', ';
			} elsif (0x42 == $next || 0x44 == $next) {	# ÅBÅD
				$mean .= '. ';
			} elsif (0x46 == $next) {		# ÅF
				$mean .= ': ';
			} elsif (0x47 == $next) {		# ÅG
				$mean .= '; ';
			} elsif (0x48 == $next) {		# ÅH
				$mean .= '? ';
			} elsif (0x49 == $next) {		# ÅI
				$mean .= '! ';
			} elsif (0x51 == $next) {		# ÅQ
				$mean .= '_';
			} elsif (0x5e == $next) {		# Å^
				$mean .= '/';
			} elsif (0x69 == $next) {		# Åi
				$mean .= '(';
			} elsif (0x6a == $next) {		# Åj
				$mean .= ')';
			} elsif (0x6d == $next) {		# Åm
				$mean .= '[';
			} elsif (0x6e == $next) {		# Ån
				$mean .= ']';
			} elsif (0x7b == $next) {		# Å{
				$mean .= '+';
			} elsif (0x7c == $next) {		# Å|
				$mean .= '-';
			} elsif (0x81 == $next) {		# ÅÅ
				$mean .= '=';
			} else {
				$mean .= pack('CC', $char, $next);
			}
		} elsif (0x82 == $char) {
			$next = shift(@list);
			if (0x4f <= $next && $next <= 0x58) {		# ÇO-ÇX
				$mean .= pack('C', $next - 0x1f);
			} elsif (0x60 <= $next && $next <= 0x79) {	# Ç`-Çy
				$mean .= pack('C', $next - 0x1f);
			} elsif (0x81 <= $next && $next <= 0x9a) {	# ÇÅ-Çö
				$mean .= pack('C', $next - 0x20);
			} else {
				$mean .= pack('CC', $char, $next);
			}
		} elsif ((0x81 < $char && $char <= 0x9f)
				|| (0xe0 <= $char && $char <= 0xfc)) {
			$mean .= pack('CC', $char, shift(@list));
		} else {
			$mean .= pack('C', $char);
		}
	}

	@list = ();
	$mean =~ s/ÅüÅy/ Åy/g;
	$mean =~ s/ ; /; /g;
	$mean =~ s/  +/ /g;
	$mean =~ s/([,\.!\?]) ([,\.])/$1$2/g;

	#
	# extract examples if any.
	#
	if ($mean =~ s/ \/ Åyópó·(?:ÅE$sjis_any_re+(?:\-[0-9]+)?)?Åz(.*)$//o) {
		$yorei = $1;
	}

	#
	# write the meaning.
	#
	$mean =~ s/\s+$//;
	if (!$fpwtext->add_text(Jcode::convert($mean, 'euc', 'sjis'))
			|| !$fpwtext->add_newline()) {
		&error("Failed to write text ($mean)", $fpwtext);
	}

	#
	# write the examples.
	#
	if ('' ne $yorei) {
		$fpwtext->add_indent_level(3);
		@list = split(/ \/ /, $yorei);
		foreach $yorei (@list) {
			$yorei =~ s/^\s+//;
			$yorei =~ s/\s+$//;
			$yorei = 'Åü ' . $yorei;
			if (!$fpwtext->add_text(Jcode::convert($yorei, 'euc', 'sjis'))
					|| !$fpwtext->add_newline()) {
				&error("Failed to write an example ($yorei)", $fpwtext);
			}
		}
		$fpwtext->add_indent_level(2);
	}
}

#
# void write_copyright(void);
# add a copyright page to the book.
#
sub write_copyright
{
	print "Writing copyright information...\n";
	open(my $copy, 'copyright.txt') ||
		&error("Failed to open: copyright.txt: $!");

	while (!$copy->eof) {
		my $line = $copy->getline;
		$line =~ s/[\r\n]+$//;
		if ($line ne '') {
			$fpwcopyright->add_text($line) ||
				&error("Failed to write text: $line", $fpwcopyright);
		}
		$fpwcopyright->add_newline() ||
			&error("Failed to add a newline", $fpwcopyright);
	}
	$copy->close;

	my $username = '(unknown user)';
	if (defined($ENV{'USER'})) {
		$username = $ENV{'USER'};
	} elsif (defined($ENV{'USERNAME'})) {
		$username = $ENV{'USERNAME'};
	}

	my ($sec, $min, $hour, $day, $mon, $year) = localtime();
	my $time = sprintf('This book is generated by %s on %02d/%02d/%02d %02d:%02d:%02d.',
			$username, $year + 1900, $mon+1, $day, $hour, $min, $sec);

	if (!$fpwcopyright->add_newline()
			|| !$fpwcopyright->add_text('--')
			|| !$fpwcopyright->add_newline()
			|| !$fpwcopyright->add_text($time)
			|| !$fpwcopyright->add_newline()) {
		&error("Failed to write compilation date and time", $fpwcopyright);
	}
}


#-----------------------------------------------------------------------#
#	message output							#
#-----------------------------------------------------------------------#
#
# jprint(char *str);
#
sub jprint
{
	my($str) = @_;

	if ($str =~ /[^\x00-\x7e]/) {
		$str = Jcode::convert($str, $opt_charset);
	}
	print $str;
}

#
# error(char *errmsg, char *func, obj);
# exit program with a error message.
#
sub error
{
	my($errmsg, $obj) = @_;

	if ($errmsg =~ /[^\x00-\x7e]/) {
		$errmsg = Jcode::convert($errmsg, $opt_charset);
	}
	if (defined($obj)) {
		$errmsg .= (': ' . $obj->error_message());
		$errmsg =~ s/:\s*$//;
	}
	die "Error: $errmsg\.\n";
}

#
# void usage(int exit_code);
#
sub usage
{
	print<<__EOM__;
Usage: $0 [-c charset] file ...
__EOM__
	exit($_[0]);
}
