use v6.d;

use NativeCall;

use SessionManager::ActionData;
use SessionManager::Actions;
use SessionManager::Command;
use SessionManager::Config;

#use Gnome::Gtk4::ApplicationWindow:api<2>;
#use Gnome::Gtk4::Box:api<2>;
use Gnome::Gtk4::Button:api<2>;
#use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Picture:api<2>;
#use Gnome::Gtk4::Grid:api<2>;
#use Gnome::Gtk4::Frame:api<2>;
use Gnome::Gtk4::T-enums:api<2>;
use Gnome::Gtk4::Overlay:api<2>;
#use Gnome::Gtk4::PopoverMenu:api<2>;
#use Gnome::Gtk4::ScrolledWindow:api<2>;

use Gnome::GdkPixbuf::Pixbuf:api<2>;
use Gnome::Gdk4::Texture:api<2>;

use Gnome::Glib::N-Error:api<2>;
use Gnome::Glib::T-error:api<2>;

use Gnome::N::N-Object:api<2>;

#use Digest::SHA256::Native;

#-------------------------------------------------------------------------------
#constant Box = Gnome::Gtk4::Box;
#constant Grid = Gnome::Gtk4::Grid;
#constant ApplicationWindow = Gnome::Gtk4::ApplicationWindow;
#constant ScrolledWindow = Gnome::Gtk4::ScrolledWindow;
constant Button = Gnome::Gtk4::Button;
#constant Label = Gnome::Gtk4::Label;
constant Picture = Gnome::Gtk4::Picture;
#constant Frame = Gnome::Gtk4::Frame;
constant Overlay = Gnome::Gtk4::Overlay;

constant Texture = Gnome::Gdk4::Texture;
constant Pixbuf = Gnome::GdkPixbuf::Pixbuf;

#-------------------------------------------------------------------------------
unit class SessionManager::Gui::ButtonCommand;
also is SessionManager::Command;

#-------------------------------------------------------------------------------
has SessionManager::ActionData $!action-data handles <
      running run-log run-error tap
      >;

#-------------------------------------------------------------------------------
submethod BUILD ( Str:D :$id, Bool :$session-button = False ) {
  my SessionManager::Actions $actions .= instance;
  $!action-data = $actions.get-action($id);
  die "Failed to find an action with id '$id'" unless ?$!action-data;
}

#-------------------------------------------------------------------------------
method execute ( --> Overlay ) {
  my Picture $picture;
  my SessionManager::Config $config .= instance;

  with $picture .= new-picture {
    .set-filename($!action-data.picture);
    .set-size-request($config.get-icon-size);

    .set-margin-top(0);
    .set-margin-bottom(0);
    .set-margin-start(0);
    .set-margin-end(0);
  }

  with my Button $button .= new-button {
    $config.set-css( .get-style-context, 'session-button');
    .set-child($picture);
    .set-tooltip-text($!action-data.tooltip);
    .register-signal( $!action-data, 'run-action', 'clicked');
  }

  my Overlay $overlay .= new-overlay;
  $overlay.set-child($button);
  my $picture-file = $!action-data.overlay-picture-file;
  if ? $picture-file and $picture-file.IO.r {
    with $picture .= new-for-paintable(
      self.set-texture($picture-file)
    ) {
      $overlay.add-overlay($picture);
      .set-halign(GTK_ALIGN_END);
      .set-valign(GTK_ALIGN_END);

      $config.set-css( .get-style-context, 'overlay-pic');
    }
  }

  $overlay
}

#-------------------------------------------------------------------------------
method set-texture ( Str $file --> Texture ) {

  # Need to use a box or resize the picture, otherwise it will
  # use up all of the overlay area if the picture is large.
  my SessionManager::Config $config .= instance;
  my $err = CArray[N-Error].new(N-Error);
  my Int ( $w, $h) = ($config.get-icon-size.List X/ 3)>>.Int;
  my Gnome::GdkPixbuf::Pixbuf $gdkpixbuf .= new-from-file-at-size(
    $file, $w, $h, $err
  );

  Texture.new-for-pixbuf($gdkpixbuf)
}
