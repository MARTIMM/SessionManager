use v6.d;

use YAMLish;

use SessionManager::Variables;
use SessionManager::Actions;
use SessionManager::Sessions;
use SessionManager::Config;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

use GnomeTools::Gtk::Dialog;
use GnomeTools::Gtk::DropDown;
use GnomeTools::Gtk::ListBox;
use GnomeTools::Gtk::ListView;

use Gnome::Gtk4::ScrolledWindow:api<2>;
use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Entry:api<2>;
use Gnome::Gtk4::Image:api<2>;
use Gnome::Gtk4::Button:api<2>;
use Gnome::Gtk4::T-enums:api<2>;

#-------------------------------------------------------------------------------
unit class SessionManager::Gui::Variables;

constant ConfigPath = '/Config/variables.yaml';
my SessionManager::Gui::Variables $instance;

constant ListBox = GnomeTools::Gtk::ListBox;
constant ListView = GnomeTools::Gtk::ListView;
constant Dialog = GnomeTools::Gtk::Dialog;

constant Entry = Gnome::Gtk4::Entry;
constant ListBoxRow = Gnome::Gtk4::ListBoxRow;
constant Label = Gnome::Gtk4::Label;
constant ScrolledWindow = Gnome::Gtk4::ScrolledWindow;
constant Grid = Gnome::Gtk4::Grid;
constant Button = Gnome::Gtk4::Button;
constant Box = Gnome::Gtk4::Box;
constant Image = Gnome::Gtk4::Image;

has SessionManager::Variables $!variables;

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

  with my Dialog $dialog .= new(
    :dialog-header('Modify Variable'), :add-statusbar, :!modal
  ) {
    my Entry $vname .= new-entry;
    my Entry $vspec .= new-entry;
#    my ListBox $variables-lb .= new(
#      :object(self), :method<set-data>, :$vname, :$vspec,
#    );

    my ListView $variables .= new(:!multi-select);
    $variables.set-setup( self, 'setup-item');
    $variables.set-bind( self, 'bind-item');
#    $variables.set-unbind( self, 'unbind-item');
    $variables.set-teardown( self, 'teardown-item');

    $variables.append($!variables.get-variables.sort: {$^a.lc leg $^b.lc});
#    $variables.append($!variables.get-variables[^3]);

    $variables.set-selection-changed(
      self, 'selection-changed', :$dialog, :$vname, :$vspec
    );



#`{{
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
}}

#    my ScrolledWindow $sw = $variables-lb.set-list(
#      [ |($!variables.get-variables)]
#    );

#    .add-content( 'Variable list', $sw, :4rows);
    .add-content( 'Variable list', $variables);
    .add-content( 'Variable name', $vname);
    .add-content( 'Specification', $vspec);

    .add-button(
      self, 'do-add-variable', 'Add', :$dialog,
      :$vname, :$vspec, :$variables, #:$variables-lb
    );

    .add-button(
      self, 'do-rename-variable', 'Rename', :$dialog,
      :$vname, :$vspec, :$variables
    );

    .add-button(
      self, 'do-modify-variable', 'Modify', :$dialog, :$vname, :$vspec
    );

    .add-button( $dialog, 'destroy-dialog', 'Done');

    .set-size-request( 600, 800);
    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-add-variable (
  Dialog :$dialog, Entry :$vname,
  Entry :$vspec, ListView :$variables, #ListBox :$variables-lb#, Grid :$vlist
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
    my Str $spec = $vspec.get-text;
    $!variables.add-variable( $variable, $spec);
#    $variables-lb.append-list($spec);
    $dialog.set-status("Variable $variable added with '$spec'");

#    my Int $c = $!variables.get-n-variables;
#    $vlist.attach( $ln, 0, $c, 1, 1);
#    $vlist.attach( $lv, 1, $c, 1, 1);
#    $sts-ok = True;
  }

#  $dialog.destroy-dialog if $sts-ok;
}

#-------------------------------------------------------------------------------
method do-rename-variable (
  Dialog :$dialog, ListBoxRow() :$row,
  Entry :$vname, Entry :$vspec, ListView :$variables, #ListBox :$variables-lb
) {
  my Str $variable = $vname.get-text;

  if !$variable {
    $dialog.set-status("No variable name specified");
  }

  elsif $variable ~~ any(|$!variables.get-variables) {
    $dialog.set-status("Variable '$variable' already defined");
  }

  else {
#`{{
    # Change the entry in the listbox, returns array of possible selections
    my Str $original-name = $variables-lb.get-selection()[0];

    # Rename the use of the variable in the variables hash.
    $!variables.rename-variable( $original-name, $variable);
#note "$?LINE $variable, $original-name, $variables-lb.get-selection()[0]";
    # Rename the use of the variable in the actions list.
    my SessionManager::Actions $actions .= new;
    $actions.subst-vars( $original-name, $variable);

    # Change the row in the listbox
    $variables-lb.reset-list([ | $!variables.get-variables ]);
    $dialog.set-status("Renamed successfully everything");
}}
  }

  # Keep dialog open for other edits
 }

#-------------------------------------------------------------------------------
method do-modify-variable ( Dialog :$dialog, Entry :$vname, Entry :$vspec ) {
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
method delete ( N-Object $parameter ) {
  note "$?LINE";
}

#-------------------------------------------------------------------------------
#--[Listview callbacks]---------------------------------------------------------
#-------------------------------------------------------------------------------
method setup-item ( --> Gnome::Gtk4::Widget ) {
  my Label $name = self.make-label;
  my Label $value = self.make-label;
  my Image $used = self.make-image;
  my Button $remove = self.make-button( 'user-trash-symbolic', $name);

  with my Grid $grid .= new-grid {
#    .set-top-margin(5);
    .attach( $used, 0, 0, 2, 2);
    .attach( $name, 2, 0, 1, 1);
    .attach( $value, 2, 1, 1, 1);
    .attach( $remove, 3, 0, 2, 2);
  }

  $grid;
}

#-------------------------------------------------------------------------------
method make-label ( --> Label ) {
  with my Label $label .= new-label {
    .set-halign(GTK_ALIGN_START);
    .set-justify(GTK_JUSTIFY_LEFT);
    .set-hexpand(True);
  }

  $label
}

#-------------------------------------------------------------------------------
method make-image ( --> Image ) {
  with my Image $image .= new-image {
#    .set-halign(GTK_ALIGN_START);
#    .set-justify(GTK_JUSTIFY_LEFT);
    .set-size-request( 50, 50);
    .set-margin-end(10);
  }

  $image
}

#-------------------------------------------------------------------------------
method make-button ( Str $icon-name, Label $name --> Button ) {
  with my Button $button .= new-button {
#    .set-halign(GTK_ALIGN_START);
#    .set-justify(GTK_JUSTIFY_LEFT);
    .set-size-request( 50, 50);
    .set-margin-start(10);
#    .set-icon-name($icon-name);
    my Str $resource = 'Delete.png';
    my Image $button-image .= new-image;
    $button-image.set-from-file(%?RESOURCES{$resource});
    .set-child($button-image);

    .register-signal( self, 'remove-variable', 'clicked', :$name);
  }

  $button
}

#-------------------------------------------------------------------------------
method bind-item ( Gnome::Gtk4::Grid() $grid, Str $name ) {
  my Str $value = $!variables.substitute-vars($!variables.get-variable($name));
  self.set-text-at( 2, 0, $name, $grid);
  self.set-text-at( 2, 1, $value, $grid);
  
  # Check if variable is used in the variables store
  my Bool $name-inuse = $!variables.is-var-in-use($name);

  # If variable is not in use in the variable store, check the
  # use of it in the actions store.
  if !$name-inuse {
    my SessionManager::Actions $actions .= new;
    $name-inuse = $actions.is-var-in-use($name);

    # If variable is not in use in the actions store, check the
    # use of it in the sessions store.
    if !$name-inuse {
      my SessionManager::Sessions $sessions .= new;
      $name-inuse = $sessions.is-var-in-use($name);
    }
  }

  self.set-image-at( 0, 0, 'green', $name, $name-inuse, $grid);
  my Button() $remove = $grid.get-child-at( 3, 0);
  $remove.set-sensitive(!$name-inuse);
}

#-------------------------------------------------------------------------------
method set-text-at ( Int $row, Int $col, Str $text, Gnome::Gtk4::Grid $grid ) {
  my Label() $label = $grid.get-child-at( $row, $col);
  $label.set-text($text);
}

#-------------------------------------------------------------------------------
method set-image-at (
  Int $row, Int $col, Str $color, Str $name,
  Bool $name-inuse, Gnome::Gtk4::Grid $grid
) {
  my Str $on-off = $name-inuse ?? 'on' !! 'off';
  my Image() $used = $grid.get-child-at( $row, $col);
  my Str $resource = $color ~ '-' ~ $on-off ~ '-256.png';
  $used.set-from-file(%?RESOURCES{$resource});
}

#-------------------------------------------------------------------------------
#method unbind-item

#-------------------------------------------------------------------------------
method teardown-item ( ) {
}

#-------------------------------------------------------------------------------
method selection-changed (
  UInt $pos, @selections, Dialog :$dialog, Entry :$vname, Entry :$vspec
) {
note "$?LINE $pos, @selections.gist(), ";
  my Str $name = @selections[0];
  $vname.set-text($name);
  my Str $value = $!variables.get-variable($name);
  $vspec.set-text($value);
}



=finish
#-------------------------------------------------------------------------------
method set-data(
  ListBox :$listbox, Label() :$row-widget, ListBoxRow() :$row,
  Entry :$vname, Entry :$vspec
) {
  my SessionManager::Config $config .= instance;
  my Label() $l = $row.get-child;
  my Str $v = $l.get-text;

  my Bool $vid-inuse = $!variables.is-var-in-use($v);
  if !$vid-inuse {
    my SessionManager::Actions $actions .= new;
    $vid-inuse = $actions.is-var-in-use($v);
  }

  if !$vid-inuse {
    my SessionManager::Sessions $sessions .= new;
    $vid-inuse = $sessions.is-var-in-use($v);
  }

  $vname.set-text($v);
  $vname.set-css-classes($vid-inuse ?? "in-use" !! "not-in-use");
  
  my Str $value = $!variables.get-variable($l.get-text);
  $vspec.set-text($value);

  $vspec.set-has-tooltip(True);
  $vspec.set-tooltip-text($!variables.substitute-vars($value));
}
