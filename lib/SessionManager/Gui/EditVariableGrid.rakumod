use v6.d;

use SessionManager::Variables;
use SessionManager::Actions;
use SessionManager::Sessions;
use SessionManager::Config;

use GnomeTools::Gtk::Dialog;
use GnomeTools::Gtk::DropDown;
use GnomeTools::Gtk::ListView;

use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Entry:api<2>;
use Gnome::Gtk4::Image:api<2>;
use Gnome::Gtk4::Button:api<2>;
use Gnome::Gtk4::T-enums:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

use YAMLish;

#-------------------------------------------------------------------------------
unit class SessionManager::Gui::EditVariableGrid;
also is Gnome::Gtk4::Grid;

#constant ConfigPath = '/Config/variables.yaml';

constant ListView = GnomeTools::Gtk::ListView;
constant Dialog = GnomeTools::Gtk::Dialog;

constant Entry = Gnome::Gtk4::Entry;
constant Label = Gnome::Gtk4::Label;
constant Grid = Gnome::Gtk4::Grid;
constant Button = Gnome::Gtk4::Button;
constant Box = Gnome::Gtk4::Box;
constant Image = Gnome::Gtk4::Image;

has SessionManager::Variables $!variables;
has ListView $!variables-view;

has Entry $!variable-name;
has Entry $!variable-spec;

#-------------------------------------------------------------------------------
submethod new ( |c --> SessionManager::Gui::EditVariableGrid ) {
  self.new-grid(|c);
}

#-------------------------------------------------------------------------------
submethod BUILD ( ) {

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

    # Select the first one
    .set-selection(0);
  }

  self.attach( $!variables-view, 0, 0, 1, 1);
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
