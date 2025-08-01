use v6.d;

use YAMLish;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

use GnomeTools::Gtk::Dialog;
use GnomeTools::Gtk::DropDown;

use Gnome::Gtk4::Entry:api<2>;
use Gnome::Gtk4::EntryBuffer:api<2>;

#-------------------------------------------------------------------------------
unit class SessionManager::Gui::Variables;

constant Entry = Gnome::Gtk4::Entry;
constant EntryBuffer = Gnome::Gtk4::EntryBuffer;

constant ConfigPath = '/Config/variables.yaml';

my SessionManager::Gui::Variables $instance;

has Hash $!variables;
has Hash $!temporary;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  $!variables = %();
  $!temporary = %();
}

#-------------------------------------------------------------------------------
method new ( ) { !!! }

#-------------------------------------------------------------------------------
method instance ( --> SessionManager::Gui::Variables ) {
  $instance //= self.bless;

  $instance
}

#-------------------------------------------------------------------------------
method add ( Hash:D $variables ) {
  $!variables = %( | $!variables, | $variables);
}

#-------------------------------------------------------------------------------
method add-from-yaml ( Str:D $path ) {
  die "File $path not found or unreadable" unless $path.IO.r;
  $!variables = %( | $!variables, | load-yaml($path.IO.slurp));
}

#-------------------------------------------------------------------------------
method save ( ) {
  ($*config-directory ~ ConfigPath).IO.spurt(save-yaml($!variables));
}

#-------------------------------------------------------------------------------
method set-temporary ( Hash:D $!temporary ) { }

#-------------------------------------------------------------------------------
method substitute-vars ( Str $t --> Str ) {

  my Str $text = $t;

  while $text ~~ m/ '$' $<variable-name> = [<alpha> | \d | '-']+ / {
    my Str $name = $/<variable-name>.Str;

    # Look in the variables Hash
    if $!variables{$name}:exists {
      $text ~~ s:g/ '$' $name /$!variables{$name}/;
    }

    # Look in the temporary Hash
    elsif $!temporary{$name}:exists {
      $text ~~ s:g/ '$' $name /$!temporary{$name}/;
    }

    # Look in the environment
    elsif %*ENV{$name}:exists {
      $text ~~ s:g/ '$' $name /%*ENV{$name}/;
    }

    # Fail and block variable by substituting $ for __
    else {
      note "No substitution yet or variable \$$name" if $*verbose;
      $text ~~ s:g/ '$' $name /___$name/;
    }
  }

  # Not substituted names are replaced by the original variable format
  $text ~~ s:g/ '___' ([<alpha> | <[0..9]> | '-']+) /\$$0/;

  $text
}

#-------------------------------------------------------------------------------
# Calls from menubar entries
#-------------------------------------------------------------------------------
method variables-add ( N-Object $parameter ) {
  note "$?LINE";

  with my GnomeTools::Gtk::Dialog $dialog .= new(
    :dialog-header('Add Variable')
  ) {
    my GnomeTools::Gtk::DropDown $variables-dd .= new;
    $variables-dd.set-selection($!variables.keys);

    .add-content( 'Check if variable exists', $variables-dd);
    .add-content( 'New variable', my Entry $vname .= new-entry);
    .add-content( 'New specification', my Entry $vspec .= new-entry);

    .add-button( self, 'do-add-variable', 'Add', :$dialog, :$vname, :$vspec);
    .add-button( $dialog, 'destroy-dialog', 'Cancel');

    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-add-variable (
  GnomeTools::Gtk::Dialog :$dialog, Entry :$vname, Entry :$vspec
) {
  my Bool $sts-ok = False;

  my Str $variable = $vname.get-buffer.get-text;
  my Str $spec = $vspec.get-buffer.get-text;

  if $variable ~~ any($!variables.keys) {
    $dialog.set-status("Variable '$variable' already defined");
  }

  else {
    $!variables{$variable} = $spec;
    $sts-ok = True;
  }

  $dialog.destroy-dialog if $sts-ok;
}


#-------------------------------------------------------------------------------
method variables-modify ( N-Object $parameter ) {
  note "$?LINE";
}

#-------------------------------------------------------------------------------
method variables-delete ( N-Object $parameter ) {
  note "$?LINE";
}

