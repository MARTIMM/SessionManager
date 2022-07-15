use v6;

#use lib '/home/marcel/Languages/Raku/Projects/question-answer/lib';
#use QA::Gui::SheetSimpleWindow;
use QA::Types;

use Desktop::Dispatcher::Application;

#-------------------------------------------------------------------------------
# Initialize global variables

# Create the application id
my Str $*application-id = 'io.github.martimm.' ~ $*PROGRAM.basename;
$*application-id ~~ s/ \. <-[.]>* $//;

my Str $*dispatcher-version = '0.2.0';
my Array $*local-options = [<version>];
my Array $*remote-options = [<group=s actions=s stop>];

# Modify paths to config data and questionaires
# Default dirs;
#   $*HOME/.config/io.github.martimm.dispatcher/Data.d
#   $*HOME/.config/io.github.martimm.dispatcher/Sets.d
#   $*HOME/.config/io.github.martimm.dispatcher/Sheets.d
my QA::Types $qa-types;
given $qa-types {
  .data-file-type(QAYAML);
  .cfgloc-userdata($*HOME ~ "/.config/$*application-id/Data.d");
  .cfgloc-sheet($*HOME ~ "/.config/$*application-id/Sheets.d");
  .cfgloc-set($*HOME ~ "/.config/$*application-id/Sets.d");

#note 'dirs: ', .list-dirs.join("\n");
}

my Desktop::Dispatcher::Application $dispatcher .= new;
exit($dispatcher.run);




=finish

#-------------------------------------------------------------------------------
sub MAIN ( Str :$dispatch-config = '', Str :$actions = '', Str :$group = '' ) {

  # modify some paths
  # default dirs;
  #   $*HOME/.config/io.github.martimm.desktop-entry-tools/Data.d
  #   $*HOME/.config/io.github.martimm.desktop-entry-tools/Sets.d
  #   $*HOME/.config/io.github.martimm.desktop-entry-tools/Sheets.d
  my QA::Types $qa-types;
  given $qa-types {
    my Str $prefix =
      $*HOME ~ '/.config/io.github.martimm.' ~ $*PROGRAM.basename;

    # Remove extension from prefix
    $prefix ~~ s/ \. <-[.]>* $//;

    .data-file-type(QAYAML);
    .cfgloc-userdata($prefix ~ '/Data.d');
    .cfgloc-sheet($prefix ~ '/Sheets.d');
    .cfgloc-set($prefix ~ '/Sets.d');

#note 'dirs: ', .list-dirs.join("\n");
  }

  note "r: ", dispatch( $actions, $group);
}

#-------------------------------------------------------------------------------
sub dispatch ( Str $actions, Str $group --> Bool ) {
  my QA::Types $qa-types .= instance;
  my Hash $config = $qa-types.qa-load( 'dispatcher', :userdata);
  my Array $cmd-list = [];
  my Bool $fail = False;
#note $config.gist;

  if ?$group {
    my Hash $ac = $config<action-groups>;
    my Array $actions-group = [$group.split('/')];

#note "\n$actions-group.gist()";
    for @$actions-group -> $ap {
#note "step: $ap";
      if $ac{$ap}:exists and $ac{$ap} ~~ Hash {
        $ac = $ac{$ap};
      }

      else {
        note "group '$group', not found";
        $fail = True;
        last;
      }
    }

    if !$fail and ?$actions {
      my Array $as = [$actions.split(',')];
      for @$as -> $a {
        if $ac<actions>{$a}:exists {
          my $cmd = make-command( $a, $ac<actions>{$a});
          $fail = True unless ?$cmd;
          $cmd-list.push: $cmd;
        }

        else {
          note "action '$a', not found in group '$group'";
          $fail = True;
          last;
        }
      }
    }

    elsif !$fail {
      for $ac<actions>.keys -> $a {
        my $cmd = make-command( $a, $ac<actions>{$a});
        $fail = True unless ?$cmd;
        $cmd-list.push: $cmd;
      }
    }
  }


  if $fail {
    note "Due to errors, command list is not executed";
  }

  else {
    for @$cmd-list -> $cmd {
      note "execute: '$cmd'";
      my Proc $proc = shell "$cmd &";
    }
  }

  $fail
}

#-------------------------------------------------------------------------------
sub make-command ( Str $action, Hash $cmd-cfg --> Str ) {
#note "\naction: $cmd-cfg.gist()";

  my Str $cmd = '';
  if $cmd-cfg<command> {
    $cmd = $cmd-cfg<command>;
  }

  else {
    note "no command found to execute for this action '$action'";
    return $cmd;
  }

  if $cmd-cfg<options>:exists {
    for @($cmd-cfg<options>) -> $opt {
      if $opt ~~ Hash {
        for $opt.kv -> $k, $v {
          $cmd ~= " $k $v";
        }
      }

      else {
#say "opt: ", $opt.WHAT;
        $cmd ~= " $opt";
      }
    }
  }

#  $cmd ~= $cmd-cfg<options>.join(' ') if $cmd-cfg<options>:exists;
  $cmd ~= ' ' ~ @($cmd-cfg<arguments>).join(' ') if $cmd-cfg<arguments>:exists;

  $cmd
}
