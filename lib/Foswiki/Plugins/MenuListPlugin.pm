# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# (c) 2009 SvenDowideit@fosiki.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html


package Foswiki::Plugins::MenuListPlugin;

# Always use strict to enforce variable scoping
use strict;

require Foswiki::Func;       # The plugins API
require Foswiki::Plugins;    # For the API version

our $VERSION = '$Rev: 3193 $';
our $RELEASE = '$Date: 2009-03-20 03:32:09 +1100 (Fri, 20 Mar 2009) $';
our $SHORTDESCRIPTION = 'Folding menu list';
our $NO_PREFS_IN_TOPIC = 1;
our $baseTopic;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }
    
    $baseTopic = $topic;

    Foswiki::Func::registerTagHandler( 'MENULIST', \&MENULIST );

    return 1;
}

# The function used to handle the %EXAMPLETAG{...}% macro
# You would have one of these for each macro you want to process.
sub MENULIST {
    my($session, $params, $theTopic, $theWeb) = @_;
    # $session  - a reference to the Foswiki session object (if you don't know
    #             what this is, just ignore it)
    # $params=  - a reference to a Foswiki::Attrs object containing
    #             parameters.
    #             This can be used as a simple hash that maps parameter names
    #             to values, with _DEFAULT being the name for the default
    #             (unnamed) parameter.
    # $theTopic - name of the topic in the query
    # $theWeb   - name of the web in the query
    # Return: the result of processing the macro. This will replace the
    # macro call in the final text.

    # For example, %EXAMPLETAG{'hamburger' sideorder="onions"}%
    # $params->{_DEFAULT} will be 'hamburger'
    # $params->{sideorder} will be 'onions'
    
    my $INCLUDE = '%INCLUDE{"'.$params->{topic}.'"}%';
    my $string = Foswiki::Func::expandCommonVariables($INCLUDE);
    $string =~ s/ {3}/\t/g;     #simplify to tabs
    my @out;
    my @list;
    my $currentTopicIndex = -1;
    
    #parse into an array containing depth and the string
    #and see if we find the current basetopic being requested
    #TODO: consider what happens with baseweb, but be careful
    foreach my $line (split(/[\n\r]+/, $string)) {
       if ($line =~ /^(\t+)\*\s+(.*)$/) {
          push(@list, {tabs=>$1, length=>length($1), string=>$2});
          if (($currentTopicIndex < 0) and ($list[$#list]{string} =~ /.*$baseTopic.*/)) {
             $currentTopicIndex = $#list;
          }
       } else {
          #not a bullet
#          last;
       }
    }

	my $mode = $params->{mode} || 'collapse';
    
	if ($mode eq 'collapse') {
	    #output spec - nothing if we're not even in the tree.
	    if ($currentTopicIndex >= 0) {
	      # show tree of options back from the current one
	      #find the node's root
	      my $startIdx = $currentTopicIndex;
	      for (; ($startIdx > 0) and ($list[$startIdx]{length} > 1); $startIdx--) {}

	#go backwards, then reverse later
	      my $lastIdx = $currentTopicIndex;
	      my $currentLevel = $list[$currentTopicIndex]{length};
	      for (my $idx = $lastIdx; $idx > 0; $idx--) {
		 if (($list[$idx]{length} == 1)) {      # 
			push(@out, $idx);
		    last;
		 }
		 if ($list[$idx]{length} <= $currentLevel) {
		    $currentLevel = $list[$idx]{length};
			push(@out, $idx);
		 }
	      }
	      @out = reverse(@out);
		    
	      #if the current node has childern, show those
	      $lastIdx = $currentTopicIndex+1;
	      if ($list[$lastIdx]{length} == (1+$list[$currentTopicIndex]{length})) {
		 for (my $idx = $lastIdx; $idx < $#list; $idx++) {
		    $lastIdx = $idx;
		    if ($list[$idx]{length} <= $list[$currentTopicIndex]{length}) {          #output until we go to level of the current again.
		       last;
		    }
		    if ($list[$idx]{length} == 1+$list[$currentTopicIndex]{length}) {     
			push(@out, $idx);
		    }
		 }
	      }
	      $currentLevel = $list[$lastIdx-1]{length};
	      for (my $idx = $lastIdx; $idx < $#list; $idx++) {
		 if (($list[$idx]{length} == 1)) {# or ($list[$idx]{length} < $list[$currentTopicIndex]{length})) {          #output until we go below the level of the current again.
		    last;
		 }
		 if ($list[$idx]{length} <= $currentLevel) {
		    $currentLevel = $list[$idx]{length};
			push(@out, $idx);
		 }
	      }
	    }
	} elsif ($mode eq 'all') {
		@out = (0..$#list);
	}
    
my $from = 0;
my $to = 9999;
if (defined($params->{showlevel}) && ($params->{showlevel} =~ /(\d*)/)) {
	$from = $to = $1;
}

my $format = $params->{format} || '$tabs* $value';
my $separator = $params->{separator} || "\n";

	my @show;
	foreach my $idx (@out) {
		if (($list[$idx]{length} >= $from) &&
			($list[$idx]{length} <= $to)) {
#			if ($list[$idx]{length} == 1) {
#				'---++++ '.$list[$idx]{string}
#			} else{
#				$list[$idx]{tabs}.'* '.$list[$_]{string}
#			}
			my $str = $format;
			$str =~ s/\$tabs/$list[$idx]{tabs}/g;
			$str =~ s/\$depth/$list[$idx]{length}/g;
			$str =~ s/\$value/$list[$idx]{string}/g;
			push(@show, $str);
		}
	}

	join($separator, @show);
}

1;
__END__
This copyright information applies to the MenuListPlugin:

# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# MenuListPlugin is # This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the Foswiki root.
