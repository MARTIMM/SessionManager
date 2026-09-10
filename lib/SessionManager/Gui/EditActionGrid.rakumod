use v6.d;

use SessionManager::Variables;
use SessionManager::Actions;
use SessionManager::Sessions;
use SessionManager::Config;

use GnomeTools::Gtk::Dialog;
use GnomeTools::Gtk::DropDown;
use GnomeTools::Gtk::ListView;
use GnomeTools::Gtk::Statusbar;

use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Entry:api<2>;
use Gnome::Gtk4::Image:api<2>;
use Gnome::Gtk4::Button:api<2>;
use Gnome::Gtk4::T-enums:api<2>;
use Gnome::Gtk4::Box:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

use Gnome::Pango::T-layout:api<2>;

#-------------------------------------------------------------------------------
unit class SessionManager::Gui::EditActionGrid;
also is Gnome::Gtk4::Grid;


constant ListView = GnomeTools::Gtk::ListView;
constant Dialog = GnomeTools::Gtk::Dialog;
constant Statusbar = GnomeTools::Gtk::Statusbar;

constant Entry = Gnome::Gtk4::Entry;
constant Label = Gnome::Gtk4::Label;
constant Grid = Gnome::Gtk4::Grid;
constant Button = Gnome::Gtk4::Button;
constant Box = Gnome::Gtk4::Box;
constant Image = Gnome::Gtk4::Image;

constant EDIT_WIDTH = 500;
constant EDIT_HEIGHT = 1000;
constant EDIT_WIDTH-CHARS = 80;

has Statusbar $!statusbar;

#-------------------------------------------------------------------------------
submethod new ( |c --> SessionManager::Gui::EditActionGrid ) {
  self.new-grid(|c);
}

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  with self {
    my Int $row = 0;
    with my Label $title = self.make-label {
      .set-use-markup(True);
      .set-markup(Q[<span size="xx-large">Actions</span>]);
      .set-halign(GTK_ALIGN_FILL);
    }
    .attach( $title, 0, $row++, 1, 1);

    my Label $vstrut1 = self.make-label;
    $vstrut1.set-text(' ');
    .attach( $vstrut1, 0, $row++, 1, 1);

#    my Grid $v = self!dialog-grid;
    .attach( self!dialog-grid, 0, $row++, 1, 1);

    $!statusbar .= new;
    .attach( $!statusbar, 0, $row++, 1, 1);

#    my Box $button-row = self!button-row;
    .attach( self!button-row, 0, $row++, 1, 1);

    my Label $vstrut2 = self.make-label;
    $vstrut2.set-text(' ');
    .attach( $vstrut2, 0, $row++, 1, 1);

#    $!variables-view = self!list-view;
#    .attach( $!variables-view,  0, $row++, 1, 1);
#  }
}

#-------------------------------------------------------------------------------
method !dialog-grid ( ) {

}

#-------------------------------------------------------------------------------
method !button-row ( ) {

}


#TODO must refactor
#-------------------------------------------------------------------------------
method make-label ( --> Label ) {
  with my Label $label .= new-label {
    .set-halign(GTK_ALIGN_START);
    .set-justify(GTK_JUSTIFY_LEFT);
    .set-hexpand(True);
    .set-wrap(True);
    .set-wrap-mode(PANGO_WRAP_WORD);
    .set-max-width-chars(EDIT_WIDTH-CHARS);
  }

  $label
}

#-------------------------------------------------------------------------------
method make-entry ( --> Entry ) {
  with my Entry $entry .= new-entry {
    .set-halign(GTK_ALIGN_FILL);
    .set-hexpand(True);
#    .set-wrap(True);
#    .set-wrap-mode(PANGO_WRAP_WORD);
#    .set-max-width-chars(EDIT_WIDTH-CHARS);
  }

  $entry
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
  my SessionManager::Variables $v .= new;
  my Str $value = $v.get-variable($name);
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
