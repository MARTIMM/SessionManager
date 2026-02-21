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
#use GnomeTools::Gtk::ListBox;
use GnomeTools::Gtk::ListView;

#use Gnome::Gtk4::ScrolledWindow:api<2>;
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

#constant ListBox = GnomeTools::Gtk::ListBox;
constant ListView = GnomeTools::Gtk::ListView;
constant Dialog = GnomeTools::Gtk::Dialog;

constant Entry = Gnome::Gtk4::Entry;
#constant ListBoxRow = Gnome::Gtk4::ListBoxRow;
constant Label = Gnome::Gtk4::Label;
#constant ScrolledWindow = Gnome::Gtk4::ScrolledWindow;
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

#--[menu entry add]-------------------------------------------------------------
method add ( N-Object $parameter ) {

  with my Dialog $dialog .= new(
    :dialog-header('Modify Variable'), :add-statusbar, :!modal
  ) {
    my Entry $vname .= new-entry;
    my Entry $vspec .= new-entry;

    my ListView $variables .= new(:!multi-select);
    $variables.set-setup( self, 'setup-item', :!add-button, :$dialog);
    $variables.set-bind( self, 'bind-item');
#    $variables.set-unbind( self, 'unbind-item');
    $variables.set-teardown( self, 'teardown-item');

    $variables.set-selection-changed(
      self, 'selection-changed', :$dialog, :$vname, :$vspec
    );

#    $variables.append($!variables.get-variables.sort: {$^a.lc leg $^b.lc});
    $variables.append($!variables.get-variables[^2]);

#    .add-content( 'Variable list', $sw, :4rows);
    .add-content( 'Variable list', $variables);
    .add-content( 'Variable name', $vname);
    .add-content( 'Specification', $vspec);

    .add-button(
      self, 'do-add-variable', 'Add', :$dialog, :$vname, :$vspec, :$variables
    );
#`{{
    .add-button(
      self, 'do-rename-variable', 'Rename', :$dialog, :$vname, :$variables
    );

    .add-button(
      self, 'do-modify-variable', 'Modify', :$dialog, :$vname, :$vspec
    );
}}
    .add-button( $dialog, 'destroy-dialog', 'Done');

    .set-size-request( 600, 800);
    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-add-variable (
  Dialog :$dialog, Entry :$vname, Entry :$vspec, ListView :$variables
) {
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
  }
}

#--[menu entry modify]----------------------------------------------------------
method modify ( N-Object $parameter ) {

  with my Dialog $dialog .= new(
    :dialog-header('Modify Variable'), :add-statusbar, :!modal
  ) {
    my Entry $vname .= new-entry;
    my Entry $vspec .= new-entry;

    my ListView $variables .= new(:!multi-select);
    $variables.set-setup( self, 'setup-item', :!add-button, :$dialog);
    $variables.set-bind( self, 'bind-item');
#    $variables.set-unbind( self, 'unbind-item');
    $variables.set-teardown( self, 'teardown-item');

    $variables.set-selection-changed(
      self, 'selection-changed', :$dialog, :$vname, :$vspec
    );
note $?LINE;

#    $variables.append($!variables.get-variables.sort: {$^a.lc leg $^b.lc});
    $variables.append($!variables.get-variables[^3]);
note $?LINE;

#    .add-content( 'Variable list', $sw, :4rows);
    .add-content( 'Variable list', $variables);
    .add-content( 'Variable name', $vname);
    .add-content( 'Specification', $vspec);

    .add-button(
      self, 'do-add-variable', 'Add', :$dialog, :$vname, :$vspec, :$variables
    );

    .add-button(
      self, 'do-rename-variable', 'Rename', :$dialog, :$vname, :$variables
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
method do-rename-variable (
  Dialog :$dialog, Entry :$vname, ListView :$variables
) {
  my Str $variable = $vname.get-text;

  if !$variable {
    $dialog.set-status("No variable name specified");
  }

  elsif $variable ~~ any(|$!variables.get-variables) {
    $dialog.set-status("Variable '$variable' already defined");
  }

  else {
    # Change the entry in the listbox, returns array of possible selections
    my Str $original-name = $variables.get-selection()[0];

    # Rename the use of the variable in the variables hash.
    $!variables.rename-variable( $original-name, $variable);
note "$?LINE $variable, $original-name, $variables.get-selection(:rows)[0]";
    # Rename the use of the variable in the actions list.
    my SessionManager::Actions $actions .= new;
    $actions.subst-vars( $original-name, $variable);

    # Change the row in the listbox
    my UInt $original-pos = $variables.get-selection(:rows)[0];
    $variables.splice( $original-pos, 1, ($variable,));
    $dialog.set-status("Renamed successfully everything");
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
method setup-item (
  Bool :$add-button = False, Dialog :$dialog,
  ListView() :_native-object($variables) --> Gnome::Gtk4::Widget
) {
  my Label $name = self.make-label;
  my Label $value = self.make-label;
  my Image $used = self.make-image;

  with my Grid $grid .= new-grid {
#    .set-top-margin(5);
    .attach( $used, 0, 0, 2, 2);
    .attach( $name, 2, 0, 1, 1);
    .attach( $value, 2, 1, 1, 1);
    if $add-button {
      my Button $remove = self.make-button(
        'user-trash-symbolic', $name, $dialog, $variables
      );
      .attach( $remove, 3, 0, 2, 2);
    }
  }

  $grid;
}

#-------------------------------------------------------------------------------
method bind-item ( Gnome::Gtk4::Grid() $grid, Str $name ) {
  my Str $value = $!variables.substitute-vars($!variables.get-variable($name));
  self.set-text-at( 2, 0, $name, $grid);
  self.set-text-at( 2, 1, $value, $grid);

  my Bool $name-inuse = self.check-variable-inuse($name);
  self.set-image-at( 0, 0, 'green', $name, $name-inuse, $grid);

  # Check if remove button is added
  my N-Object $n-remove = $grid.get-child-at( 3, 0);
  if ?$n-remove {
    my Button() $remove = $n-remove;
    $remove.set-sensitive(!$name-inuse);
  }
}

#-------------------------------------------------------------------------------
method check-variable-inuse ( Str:D $name --> Bool ) {
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
  
  $name-inuse
}

#-------------------------------------------------------------------------------
#method unbind-item

#-------------------------------------------------------------------------------
method teardown-item ( Gnome::Gtk4::Grid() $grid ) {
  $grid.clear-object;
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
method make-button (
  Str $icon-name, Label $name, Dialog $dialog, ListView $variables  --> Button
) {
  with my Button $button .= new-button {
#    .set-halign(GTK_ALIGN_START);
#    .set-justify(GTK_JUSTIFY_LEFT);
    .set-size-request( 50, 50);
    .set-margin-start(10);
    .set-margin-end(20);
#    .set-icon-name($icon-name);
    my Image $button-image .= new-from-icon-name($icon-name);
    $button-image.set-pixel-size(64);
#      .set-from-file(%?RESOURCES<Delete.png>);
    .set-child($button-image);

    .register-signal(
      self, 'do-remove-variable', 'clicked', :$name, :$dialog, :$variables
    );
  }

  $button
}

#-------------------------------------------------------------------------------
method selection-changed (
  UInt $pos, @selections, Dialog :$dialog, Entry :$vname, Entry :$vspec
) {
  my Str $name = @selections[0];
  $vname.set-text($name);
  my Str $value = $!variables.get-variable($name);
  $vspec.set-text($value);
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

#--[menu entry delete]----------------------------------------------------------
method delete ( N-Object $parameter ) {

  with my Dialog $dialog .= new(
    :dialog-header('Modify Variable'), :add-statusbar, :!modal
  ) {
#    my Entry $vname .= new-entry;
#    my Entry $vspec .= new-entry;

    my ListView $variables .= new(:!multi-select);
    $variables.set-setup( self, 'setup-item', :add-button, :$dialog);
    $variables.set-bind( self, 'bind-item');
#    $variables.set-unbind( self, 'unbind-item');
    $variables.set-teardown( self, 'teardown-item');

#    $variables.set-selection-changed(
#      self, 'selection-changed', :$dialog, :$vname, :$vspec
#    );

    $variables.append($!variables.get-variables.sort: {$^a.lc leg $^b.lc});
#    $variables.append($!variables.get-variables[^3]);

#    .add-content( 'Variable list', $sw, :4rows);
#    .add-content( 'Variable list', $variables);
#    .add-content( 'Variable name', $vname);
#    .add-content( 'Specification', $vspec);
#`{{
    .add-button(
      self, 'do-add-variable', 'Add', :$dialog, :$vname, :$vspec, :$variables
    );

    .add-button(
      self, 'do-rename-variable', 'Rename', :$dialog, :$vname, :$variables
    );

    .add-button(
      self, 'do-modify-variable', 'Modify', :$dialog, :$vname, :$vspec
    );
}}
    .add-button( $dialog, 'destroy-dialog', 'Done');

    .set-size-request( 600, 800);
    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-remove-variable (
  Label :$name, Dialog :$dialog, ListView :$variables
) {
  # Remove but check first if in use. It is possible that the entry
  # is changed because several dialogs can be opened next to each other
  # changing its state.
  my Str $name-var = $name.get-text;
  if self.check-variable-inuse($name-var) {
    $dialog.set-status("Variable '$name-var' is in use");
  }

  else {
    $variables.splice();
    $!variables.remove-variable($name-var);
    $dialog.set-status("Variable '$name-var' removed");
  }
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
