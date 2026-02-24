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
use GnomeTools::Gtk::ListView;

use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Entry:api<2>;
use Gnome::Gtk4::Image:api<2>;
use Gnome::Gtk4::Button:api<2>;
use Gnome::Gtk4::T-enums:api<2>;

#-------------------------------------------------------------------------------
unit class SessionManager::Gui::Variables;

constant ConfigPath = '/Config/variables.yaml';

constant ListView = GnomeTools::Gtk::ListView;
constant Dialog = GnomeTools::Gtk::Dialog;

constant Entry = Gnome::Gtk4::Entry;
constant Label = Gnome::Gtk4::Label;
constant Grid = Gnome::Gtk4::Grid;
constant Button = Gnome::Gtk4::Button;
constant Box = Gnome::Gtk4::Box;
constant Image = Gnome::Gtk4::Image;

# Singleton hook
my SessionManager::Gui::Variables $instance;

has Dialog $!dialog;
has Entry $!variable-name;
has Entry $!variable-spec;

has SessionManager::Variables $!variables;
has ListView $!variables-view;
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

  $!variable-name .= new-entry;
  $!variable-spec .= new-entry;

  with $!variables-view .= new(:!multi-select) {
    .set-setup( self, 'setup-item');
    .set-bind( self, 'bind-item');
#    .set-unbind( self, 'unbind-item');
    .set-teardown( self, 'teardown-item');

    .set-selection-changed( self, 'selection-changed');

    .append($!variables.get-variables.sort: {$^a.lc leg $^b.lc});
#    .append($!variables.get-variables[^2]);
  }

  with $!dialog .= new(
    :dialog-header('Add Variable'), :add-statusbar, :!modal
  ) {
    .add-content( 'Variable list', $!variables-view);
    .add-content( 'Variable name', $!variable-name);
    .add-content( 'Specification', $!variable-spec);

    .add-button( self, 'do-add-variable', 'Add');
    .add-button( $!dialog, 'destroy-dialog', 'Done');

    .set-size-request( 600, 800);
    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-add-variable ( ) {
  my Str $variable = $!variable-name.get-text;

  if !$variable {
    $!dialog.set-status("No variable name specified");
  }

  elsif $variable ~~ any(|$!variables.get-variables) {
    $!dialog.set-status("Variable '$variable' already defined");
  }

  else {
    my Str $spec = $!variable-spec.get-text;
    $!variables.add-variable( $variable, $spec);
    $!dialog.set-status("Variable '$variable' added with '$spec'");
    my UInt $original-pos = $!variables-view.get-selection(:rows)[0];
    $!variables-view.splice( $original-pos, 0, $variable);
  }
}

#--[menu entry modify]----------------------------------------------------------
method modify ( N-Object $parameter ) {

  $!variable-name .= new-entry;
  $!variable-spec .= new-entry;

  with $!variables-view .= new(:!multi-select) {
    .set-setup( self, 'setup-item');
    .set-bind( self, 'bind-item');
#    .set-unbind( self, 'unbind-item');
    .set-teardown( self, 'teardown-item');

    .set-selection-changed( self, 'selection-changed');

    .append($!variables.get-variables.sort: {$^a.lc leg $^b.lc});
#    .append($!variables.get-variables[^2]);
  }

  with $!dialog .= new(
    :dialog-header('Modify Variable'), :add-statusbar, :!modal
  ) {
    .add-content( 'Variable list', $!variables-view);
    .add-content( 'Variable name', $!variable-name);
    .add-content( 'Specification', $!variable-spec);

    .add-button( self, 'do-rename-variable', 'Rename');
    .add-button( self, 'do-modify-variable', 'Modify');
    .add-button( $!dialog, 'destroy-dialog', 'Done');

    .set-size-request( 600, 800);
    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-rename-variable ( ) {
  my Str $variable = $!variable-name.get-text;

  if !$variable {
    $!dialog.set-status("No variable name specified");
  }

  elsif $variable ~~ any(|$!variables.get-variables) {
    $!dialog.set-status("Variable '$variable' already defined");
  }

  else {
    # Change the entry in the listview, returns array of possible selections
    my Str $original-name = $!variables-view.get-selection()[0];

    # Rename the use of the variable in the variables hash.
    $!variables.rename-variable( $original-name, $variable);

    # Rename the use of the variable in the actions list.
    my SessionManager::Actions $actions .= new;
    $actions.subst-vars( $original-name, $variable);

    # Change the row in the listview
    my UInt $original-pos = $!variables-view.get-selection(:rows)[0];
    $!variables-view.splice( $original-pos, 1, $variable);
    $!dialog.set-status("Renamed successfully everything");
  }

  # Keep dialog open for other edits
 }

#-------------------------------------------------------------------------------
method do-modify-variable ( ) {
  my Str $variable = $!variable-name.get-text;
  if !$variable {
    $!dialog.set-status("No variable name specified");
  }

  else {
    my Str $variable-spec = $!variable-spec.get-text;
    $!variables.set-variable( $variable, $variable-spec);
    $!dialog.set-status("Variable $variable modified to '$variable-spec'");

    # Change the row in the listview
    my UInt $original-pos = $!variables-view.get-selection(:rows)[0];
    $!variables-view.splice( $original-pos, 1, $variable);
    $!dialog.set-status("Renamed successfully everything");
  }
}

#--[menu entry delete]----------------------------------------------------------
method delete ( N-Object $parameter ) {

  $!variable-name .= new-entry;
  $!variable-spec .= new-entry;

  with $!variables-view .= new(:!multi-select) {
    .set-setup( self, 'setup-item');
    .set-bind( self, 'bind-item');
#    .set-unbind( self, 'unbind-item');
    .set-teardown( self, 'teardown-item');

    .set-selection-changed( self, 'selection-changed');

    .append($!variables.get-variables.sort: {$^a.lc leg $^b.lc});
#    .append($!variables.get-variables[^2]);
  }

  with $!dialog .= new(
    :dialog-header('Modify Variable'), :add-statusbar, :!modal
  ) {
    .add-content( 'Variable list', $!variables-view);
    .add-content( 'Variable name', $!variable-name);

    .add-button( self, 'do-remove-variable', 'Remove');
    .add-button( $!dialog, 'destroy-dialog', 'Done');

    .set-size-request( 600, 800);
    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-remove-variable ( ) {
  # Remove but check first if in use. It is possible that the entry
  # is changed because several dialogs can be opened next to each other
  # changing its state.
  my Str $name-var = $!variable-name.get-text;
  if self.check-variable-inuse($name-var) {
    $!dialog.set-status("Variable '$name-var' is in use");
  }

  else {
    my UInt $original-pos = $!variables-view.get-selection(:rows)[0];
    $!variables-view.splice( $original-pos, 1);
    $!variables.remove-variable($name-var);
    $!dialog.set-status("Variable '$name-var' removed");
  }
}

#-------------------------------------------------------------------------------
method setup-item ( ) {
  my Label $name = self.make-label;
  my Label $value = self.make-label;
  my Image $used = self.make-image;

  with my Grid $grid .= new-grid {
    .attach( $used, 0, 0, 2, 2);
    .attach( $name, 2, 0, 1, 1);
    .attach( $value, 2, 1, 1, 1);
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
    .set-size-request( 40, 40);
    .set-margin-end(10);
  }

  $image
}

#-------------------------------------------------------------------------------
method selection-changed ( UInt $pos, @selections ) {
  my Str $name = @selections[0];
  $!variable-name.set-text($name);
  my Str $value = $!variables.get-variable($name);
  $!variable-spec.set-text($value);
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
