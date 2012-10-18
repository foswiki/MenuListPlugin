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

our $VERSION           = '2.0';
our $RELEASE           = '18-Nov-2012';
our $SHORTDESCRIPTION  = 'dynamic Folding menu list';
our $NO_PREFS_IN_TOPIC = 1;
our $baseWeb;
our $baseTopic;
our $sessionUser;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    $baseTopic   = $topic;
    $baseWeb     = $web;
    $sessionUser = $user;

    Foswiki::Func::registerTagHandler( 'MENULIST', \&MENULIST );

    return 1;
}

# The function used to handle the %EXAMPLETAG{...}% macro
# You would have one of these for each macro you want to process.
sub MENULIST {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

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

    my $INCLUDE = '%INCLUDE{"' . $params->{topic} . '"}%';
    my $string  = Foswiki::Func::expandCommonVariables($INCLUDE) . "\n";
    $string =~ s/ {3}/\t/g;    #simplify to tabs
    my @list;
    my $currentTopicIndex = -1;

    my $from = 0;
    my $to   = 9999;

    #parse into an array containing depth and the string
    #and see if we find the current basetopic being requested
    #TODO: consider what happens with baseweb, but be careful
    foreach my $line ( split( /[\n\r]+/, $string ) ) {
        if ( $line =~ /^(\t+)\*\s+(.*)$/ ) {
            push( @list, { tabs => $1, length => length($1), string => $2 } );

            my $webTopicRegex = "$baseWeb.$baseTopic";

            #deal with both dots and slashes as web separators
            $webTopicRegex =~ s/[.\/]/[.\/]/g;
            if (    ( $currentTopicIndex < 0 )
                and ( $list[$#list]{string} =~ /$webTopicRegex/ ) )
            {
                $currentTopicIndex = $#list;
            }
        }
        else {

            #not a bullet
        }
    }

    my $mode = $params->{mode} || 'collapse';

    my @out;
    if ( $mode eq 'collapse' ) {
        if ( $currentTopicIndex == -1 ) {

            #original spec - nothing if we're not even in the tree.
            if ( Foswiki::Func::isTrue( $params->{quiet} ) ) {

            }
            else {

                #instead, show all first level items
                @out = ( 0 .. $#list );
                $from = $to = 1;
            }
        }
        else {

            #go backwards from current Topic to root
            my $lastIdx      = $currentTopicIndex;
            my $currentLevel = $list[$currentTopicIndex]{length};
            for ( my $idx = $lastIdx ; $idx > 0 ; $idx-- ) {
                if ( ( $list[$idx]{length} == 1 ) ) {
                    $lastIdx = $idx;
                    push( @out, $idx );
                    last;
                }
                if ( $list[$idx]{length} <= $currentLevel ) {
                    $currentLevel = $list[$idx]{length};
                    $lastIdx      = $idx;
                    push( @out, $idx );
                }
            }
            @out = reverse(@out);

            #if the current node has children, show those
            $lastIdx      = $currentTopicIndex;
            $currentLevel = $list[$lastIdx]{length};
            if ( ( $lastIdx <= $#list ) ) {
                for ( my $idx = $lastIdx + 1 ; $idx <= $#list ; $idx++ ) {
                    if ( $list[$idx]{length} <= $currentLevel )
                    {    #output until we go to level of the current again.
                        last;
                    }
                    if ( $list[$idx]{length} == 1 + $currentLevel ) {
                        $lastIdx = $idx;
                        push( @out, $idx );
                    }
                }
            }
            $currentLevel = $list[$lastIdx]{length};
            for ( my $idx = $lastIdx + 1 ; $idx <= $#list ; $idx++ ) {
                if ( $list[$idx]{length} <= $currentLevel ) {
                    $currentLevel = $list[$idx]{length};
                    push( @out, $idx );
                }
            }
        }
    }
    elsif ( $mode eq 'all' ) {
        @out = ( 0 .. $#list );
    }

    if ( defined( $params->{showlevel} )
        && ( $params->{showlevel} =~ /(\d*)/ ) )
    {
        $from = $to = $1;
    }
    if ( defined( $params->{levels} )
        && ( $params->{levels} =~ /(\d*)/ ) )
    {
        $to = $from + $1;
    }

    my $format    = $params->{format}    || '$tabs* $value';
    my $separator = $params->{separator} || "\n";

    my @show;
    foreach my $idx (@out) {
        if (   ( $list[$idx]{length} >= $from )
            && ( $list[$idx]{length} <= $to ) )
        {
            if ( $from > 0 ) {
                if ( ( $from - 1 ) > length( $list[$idx]{tabs} ) ) {
                    print STDERR "PARSE ERROR: -$from--"
                      . $list[$idx]{tabs} . "--"
                      . $list[$idx]{length} . "--"
                      . $list[$idx]{string} . "-\n";
                }
                else {
                    $list[$idx]{tabs} = substr( $list[$idx]{tabs}, $from - 1 );
                }
            }

            if ( !Foswiki::Func::isTrue( $params->{showdenied}, 0 ) ) {

                #copied from Foswiki::Render..

                # Spaced-out Wiki words with alternative link text
                # i.e. [[$1][$3]]
                my $webtopic;
                if ( $list[$idx]{string} =~
                    /\[\[([^\]\[\n]+)\](\[([^\]\n]+)\])?\]/ )
                {
                    $webtopic = $1;

                 #                    } elsif ($list[$idx]{string} =~ s($STARTWW
                }
                elsif (
                    $list[$idx]{string} =~ /
                        (?:($Foswiki::regex{webNameRegex})\.)?
                        ($Foswiki::regex{wikiWordRegex}|
                            $Foswiki::regex{abbrevRegex})
                        ($Foswiki::regex{anchorRegex})?/xom
                  )
                {
                    $webtopic = ( defined($1) ? $1 . '.' . $2 : $2 );
                }
                my ( $w, $t ) =
                  Foswiki::Func::normalizeWebTopicName( $baseWeb, $webtopic );
                my $permitted = (
                    Foswiki::Func::checkAccessPermission(
                        'VIEW', $sessionUser, undef, $t, $w
                    )
                );

        #print STDERR "---$sessionUser is $permitted allowed to view $w . $t\n";
                next unless $permitted;

   #TODO: it'd be faster to skip the entire branch once we find one that is out.
            }

            my $str = $format;
            $str =~ s/\$tabs/$list[$idx]{tabs}/g;
            $str =~ s/\$depth/$list[$idx]{length}/g;
            $str =~ s/\$value/$list[$idx]{string}/g;
            push( @show, $str );
        }
    }

    join( $separator, @show );
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
