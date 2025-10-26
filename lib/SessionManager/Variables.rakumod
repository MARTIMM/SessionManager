use v6.d;

use YAMLish;

#`{{
use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

use GnomeTools::Gtk::Dialog;
use GnomeTools::Gtk::DropDown;

use Gnome::Gtk4::ScrolledWindow:api<2>;
use Gnome::Gtk4::ListBox:api<2>;
use Gnome::Gtk4::ListBoxRow:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Entry:api<2>;
use Gnome::Gtk4::T-enums:api<2>;
}}

#-------------------------------------------------------------------------------
unit class SessionManager::Variables;

constant ConfigPath = '/Config/variables.yaml';
#my SessionManager::Gui::Variables $instance;

#`{{
constant Entry = Gnome::Gtk4::Entry;
constant ListBox = Gnome::Gtk4::ListBox;
constant ListBoxRow = Gnome::Gtk4::ListBoxRow;
constant Label = Gnome::Gtk4::Label;
constant ScrolledWindow = Gnome::Gtk4::ScrolledWindow;
}}

my Hash $variables = %();
my Hash $temporary = %();
#has Str $!original-name;
#has ListBoxRow $!original-row;


#`{{
#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  $variables = %();
  $temporary = %();
}

#-------------------------------------------------------------------------------
method new ( ) { !!! }

#-------------------------------------------------------------------------------
method instance ( --> SessionManager::Gui::Variables ) {
  $instance //= self.bless;

  $instance
}
}}

#-------------------------------------------------------------------------------
method add ( Hash:D $v ) {
  for $v.kv -> $k, $v {
    $variables{$k} = $v;
  }
}

#-------------------------------------------------------------------------------
method add-from-yaml ( Str:D $path ) {
  die "File $path not found or unreadable" unless $path.IO.r;
  $variables = %( | $variables, | load-yaml($path.IO.slurp));
}

#-------------------------------------------------------------------------------
method save ( ) {
  ($*config-directory ~ ConfigPath).IO.spurt(save-yaml($variables));
}

#-------------------------------------------------------------------------------
method load ( ) {
  if ($*config-directory ~ ConfigPath).IO.r {
    $variables = load-yaml(($*config-directory ~ ConfigPath).IO.slurp);
  }
}

#-------------------------------------------------------------------------------
method add-variable ( Str:D $name, Str:D $value --> Str ) {
  $variables{$name} = $value;
}

#-------------------------------------------------------------------------------
method get-variables ( --> Seq ) {
  $variables.keys
}

#-------------------------------------------------------------------------------
method get-n-variables ( --> Int ) {
  $variables.elems
}

#-------------------------------------------------------------------------------
method get-variable ( Str:D $name --> Str ) {
  $variables{$name}
}

#-------------------------------------------------------------------------------
method set-variable ( Str:D $name, Str:D $value --> Str ) {
  $variables{$name} = $value;
}

#-------------------------------------------------------------------------------
method rename-variable ( Str:D $old-var, Str:D $new-var ) {
  $variables{$new-var} = $variables{$old-var}:delete;

  for $variables.keys -> $variable-name {
    $variables{$variable-name} ~~ s:g/ '$' $old-var  (<-[\w-]>) /\$$new-var$0/;
#    $actions-object.subst-vars( $!original-name, $variable);
  }
}

#-------------------------------------------------------------------------------
#method set-temporary ( Hash:D $temporary ) { }

#-------------------------------------------------------------------------------
method substitute-vars ( Str $t --> Str ) {

  my Str $text = $t;

  while $text ~~ m/ '$' $<variable-name> = <[\w-]>+ / {
    my Str $name = $/<variable-name>.Str;
#note "$?LINE $name";
    # Look in the variables Hash
    if $variables{$name}:exists {
      $text ~~ s:g/ '$' $name (<-[\w-]>?) /$variables{$name}$0/;
    }

    # Look in the temporary Hash
    elsif $temporary{$name}:exists {
      $text ~~ s:g/ '$' $name (<-[\w-]>?) /$temporary{$name}$0/;
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

#-------------------------------------------------------------------------------
method is-var-in-use ( Str $v --> Bool ) {
  my Bool $in-use = False;

  for $variables.kv -> $k, $text {
    next if $k eq $v;

    if $text ~~ m/ '$' $v <-[\w-]>? / {
      $in-use = True;
      last;
    }
  }
  
note "$?LINE $v in use: $in-use";

  $in-use
}














=finish
#-------------------------------------------------------------------------------
# Calls from menubar entries
#-------------------------------------------------------------------------------
method variables-add-modify (
  N-Object $parameter, :extra-data($actions-object)
) {
  with my GnomeTools::Gtk::Dialog $dialog .= new(
    :dialog-header('Modify Variable'), :add-statusbar
  ) {
    #my GnomeTools::Gtk::DropDown $variables-dd .= new;
    #$variables-dd.set-selection($variables.keys.sort);
    my ListBox $variables-lb .= new-listbox;
    for $variables.keys.sort -> $v {
      with my Label $l .= new-with-mnemonic($v) {
        .set-justify(GTK_JUSTIFY_LEFT);
        .set-halign(GTK_ALIGN_START);
      }
      $variables-lb.append($l);
    }

    with my ScrolledWindow $sw .= new-scrolledwindow {
      .set-child($variables-lb);
      .set-size-request( 400, 200);
    }

    .add-content( 'Variable list', $sw);
    .add-content( 'Variable name', my Entry $vname .= new-entry);
    .add-content( 'Specification', my Entry $vspec .= new-entry);

    .add-button(
      self, 'do-rename-variable', 'Rename',
      :$dialog, :$vname, :$vspec, :$actions-object
    );

    .add-button(
      self, 'do-add-variable', 'Add', :$dialog, :$vname, :$vspec
    );

    .add-button(
      self, 'do-modify-variable', 'Modify', :$dialog, :$vname, :$vspec
    );

    .add-button( $dialog, 'destroy-dialog', 'Cancel');

    $variables-lb.register-signal(
      self, 'set-data', 'row-selected', :$vname, :$vspec
    );

    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-rename-variable (
  GnomeTools::Gtk::Dialog :$dialog, ListBoxRow() :$row,
  Entry :$vname, Entry :$vspec, :$actions-object
) {
  my Str $variable = $vname.get-text;

  if !$variable {
    $dialog.set-status("No variable name specified");
  }

  elsif $variable ~~ any(|$variables.keys) {
    $dialog.set-status("Variable '$variable' already defined");
  }

  else {
    $variables{$variable} = $variables{$!original-name}:delete;
    for $variables.keys -> $variable-name {
      my Str $on = $!original-name;
      $variables{$variable-name} ~~ s:g/ '$' $on  (<-[\w-]>) /\$$variable$0/;
      $actions-object.subst-vars( $!original-name, $variable);
    }

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
  GnomeTools::Gtk::Dialog :$dialog, Entry :$vname, Entry :$vspec
) {
  my Bool $sts-ok = False;

  my Str $variable = $vname.get-text;

  if !$variable {
    $dialog.set-status("No variable name specified");
  }

  elsif $variable ~~ any(|$variables.keys) {
    $dialog.set-status("Variable '$variable' already defined");
  }

  else {
    $variables{$variable} = $vspec.get-text;
    $sts-ok = True;
  }

  $dialog.destroy-dialog if $sts-ok;
}

#-------------------------------------------------------------------------------
method do-modify-variable (
  GnomeTools::Gtk::Dialog :$dialog, Entry :$vname, Entry :$vspec
) {
  my Bool $sts-ok = False;

  my Str $variable = $vname.get-text;

  if !$variable {
    $dialog.set-status("No variable name specified");
  }

  else {
    $variables{$variable} = $vspec.get-text;
    $sts-ok = True;
  }

  $dialog.destroy-dialog if $sts-ok;
}

#-------------------------------------------------------------------------------
method set-data( ListBoxRow() $row, Entry :$vname, Entry :$vspec ) {

  # Needed to rename content of row
  $!original-row = $row;

  my Label() $l = $row.get-child;
  $!original-name = $l.get-text;
  $vname.set-text($l.get-text);
  $vspec.set-text($variables{$l.get-text});
}

#-------------------------------------------------------------------------------
method variables-delete ( N-Object $parameter ) {
  note "$?LINE";
}

