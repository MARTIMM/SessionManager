use v6.d;

use YAMLish;

use SessionManager::Variables;
use SessionManager::Actions;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

use GnomeTools::Gtk::Dialog;
use GnomeTools::Gtk::DropDown;
use GnomeTools::Gtk::ListBox;

use Gnome::Gtk4::ScrolledWindow:api<2>;
#use Gnome::Gtk4::ListBox:api<2>;
#use Gnome::Gtk4::ListBoxRow:api<2>;
use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Entry:api<2>;
use Gnome::Gtk4::T-enums:api<2>;


#-------------------------------------------------------------------------------
unit class SessionManager::Gui::Variables;

constant ConfigPath = '/Config/variables.yaml';
my SessionManager::Gui::Variables $instance;

constant ListBox = GnomeTools::Gtk::ListBox;

constant Entry = Gnome::Gtk4::Entry;
#constant ListBox = Gnome::Gtk4::ListBox;
constant ListBoxRow = Gnome::Gtk4::ListBoxRow;
constant Label = Gnome::Gtk4::Label;
constant ScrolledWindow = Gnome::Gtk4::ScrolledWindow;
constant Grid = Gnome::Gtk4::Grid;

has SessionManager::Variables $!variables;

#has Hash $!temporary;
has Str $!original-name;
has ListBoxRow $!original-row;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  $!variables .= new;
}

#-------------------------------------------------------------------------------
method new ( ) { !!! }

#-------------------------------------------------------------------------------
method instance ( --> SessionManager::Gui::Variables ) {
  $instance //= self.bless;

  $instance
}

#`{{
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
method load ( ) {
  if ($*config-directory ~ ConfigPath).IO.r {
    $!variables = load-yaml(($*config-directory ~ ConfigPath).IO.slurp);
  }
}

#-------------------------------------------------------------------------------
method set-temporary ( Hash:D $!temporary ) { }

#-------------------------------------------------------------------------------
method substitute-vars ( Str $t --> Str ) {

  my Str $text = $t;

  while $text ~~ m/ '$' $<variable-name> = <[\w-]>+ / {
    my Str $name = $/<variable-name>.Str;
#note "$?LINE $name";
    # Look in the variables Hash
    if $!variables{$name}:exists {
      $text ~~ s:g/ '$' $name (<-[\w-]>?) /$!variables{$name}$0/;
    }

    # Look in the temporary Hash
    elsif $!temporary{$name}:exists {
      $text ~~ s:g/ '$' $name (<-[\w-]>?) /$!temporary{$name}$0/;
    }

    # Look in the environment
    elsif %*ENV{$name}:exists {
      $text ~~ s:g/ '$' $name (<-[\w-]>?) /%*ENV{$name}$0/;
    }

    # Fail and block variable by substituting $ for __
    else {
      note "No substitution yet or variable \$$name" if $*verbose;
      $text ~~ s:g/ '$' $name (<-[\w-]>?) /___$name$0/;
    }
#note "$?LINE $text";
  }

  # Not substituted names are replaced by the original variable format
  $text ~~ s:g/ '___' (<[\w-]>+) /\$$0/;

  $text
}
}}

#-------------------------------------------------------------------------------
# Calls from menubar entries
#-------------------------------------------------------------------------------
method add-modify ( N-Object $parameter ) {
  with my GnomeTools::Gtk::Dialog $dialog .= new(
    :dialog-header('Modify Variable'), :add-statusbar
  ) {
    #my GnomeTools::Gtk::DropDown $variables-dd .= new;
    #$variables-dd.set-selection($!variables.keys.sort);
#`{{
my ListBox $list-lb .= new(
  :$object, :method<set-data>, :$multi, |%options
);

$variables-lb.register-signal(
  self, 'set-data', 'row-selected', :$vname, :$vspec
);
}}
    my Entry $vname .= new-entry;
    my Entry $vspec .= new-entry;
    my Int $row-count = 0;
    my Grid $vlist .= new-grid;
    $vlist.set-column-spacing(15);
    for $!variables.get-variables.sort({$^a.lc cmp $^b.lc}) -> $v {
      with my Label $ln .= new-label {
        .set-text($v);
        .set-justify(GTK_JUSTIFY_LEFT);
        .set-halign(GTK_ALIGN_START);
      }
      with my Label $lv .= new-label {
        .set-text($!variables.get-variable($v));
        .set-justify(GTK_JUSTIFY_LEFT);
        .set-halign(GTK_ALIGN_START);
      }

      $vlist.attach( $ln, 0, $row-count, 1, 1);
      $vlist.attach( $lv, 1, $row-count, 1, 1);
      $row-count++;
    }

    with my ScrolledWindow $sw .= new-scrolledwindow {
      .set-child($vlist);
      .set-size-request( 850, 300);
    }

#`{{
    with my ScrolledWindow $sw .= new-scrolledwindow {
      .set-child($variables-lb);
      .set-size-request( 400, 200);
    }
}}

    .add-content( 'Variable list', $sw, :4rows);
    .add-content( 'Variable name', $vname);
    .add-content( 'Specification', $vspec);

    .add-button(
      self, 'do-rename-variable', 'Rename', :$dialog, :$vname, :$vspec
    );

    .add-button(
      self, 'do-add-variable', 'Add', :$dialog, :$vname, :$vspec, :$vlist
    );

    .add-button(
      self, 'do-modify-variable', 'Modify', :$dialog, :$vname, :$vspec
    );

    .add-button( $dialog, 'destroy-dialog', 'Done');

    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-rename-variable (
  GnomeTools::Gtk::Dialog :$dialog, ListBoxRow() :$row,
  Entry :$vname, Entry :$vspec
) {
  my Str $variable = $vname.get-text;

  if !$variable {
    $dialog.set-status("No variable name specified");
  }

  elsif $variable ~~ any(|$!variables.get-variables) {
    $dialog.set-status("Variable '$variable' already defined");
  }

  else {
    my SessionManager::Actions $actions;
    $!variables.rename-variable( $!original-name, $variable);
    $actions.subst-vars( $!original-name, $variable);

    # Change the row in the listbox
    with my Label $l .= new-with-mnemonic($variable) {
      .set-justify(GTK_JUSTIFY_LEFT);
      .set-halign(GTK_ALIGN_START);
    }
    $!original-row.set-child($l);

    $!original-name = $variable;

    $dialog.set-status("Renamed successfully everything");
  }

  # Keep dialog open for other edits
 }

#-------------------------------------------------------------------------------
method do-add-variable (
  GnomeTools::Gtk::Dialog :$dialog, Entry :$vname,
  Entry :$vspec, Grid :$vlist
) {
#  my Bool $sts-ok = False;

  my Str $variable = $vname.get-text;

  if !$variable {
    $dialog.set-status("No variable name specified");
  }

  elsif $variable ~~ any(|$!variables.get-variables) {
    $dialog.set-status("Variable '$variable' already defined");
  }

  else {
    my Str $var = $vspec.get-text;
    $!variables.add-variable( $variable, $var);
    $dialog.set-status("Variable $variable added with '$var'");
    with my Label $ln .= new-with-mnemonic($variable) {
      .set-justify(GTK_JUSTIFY_LEFT);
      .set-halign(GTK_ALIGN_START);
    }
    with my Label $lv .= new-with-mnemonic($var) {
      .set-justify(GTK_JUSTIFY_LEFT);
      .set-halign(GTK_ALIGN_START);
    }

    my Int $c = $!variables.get-n-variables;
    $vlist.attach( $ln, 0, $c, 1, 1);
    $vlist.attach( $lv, 1, $c, 1, 1);
#    $sts-ok = True;
  }

#  $dialog.destroy-dialog if $sts-ok;
}

#-------------------------------------------------------------------------------
method do-modify-variable (
  GnomeTools::Gtk::Dialog :$dialog, Entry :$vname, Entry :$vspec
) {
#  my Bool $sts-ok = False;

  my Str $variable = $vname.get-text;

  if !$variable {
    $dialog.set-status("No variable name specified");
  }

  else {
    $!variables.set-variable( $variable, $vspec.get-text);
    $dialog.set-status("Variable $variable modified to '$vspec.get-text()'");
#    $sts-ok = True;
  }

#  $dialog.destroy-dialog if $sts-ok;
}

#-------------------------------------------------------------------------------
method set-data(
  Label() :$row-widget, ListBoxRow() :$row, Entry :$vname, Entry :$vspec
) {

  # Needed to rename content of row
  $!original-row = $row;

  my Label() $l = $row.get-child;
  $!original-name = $l.get-text;
  $vname.set-text($l.get-text);
  $vspec.set-text($!variables.get-variable($l.get-text));
}

#-------------------------------------------------------------------------------
method delete ( N-Object $parameter ) {
  note "$?LINE";
}

