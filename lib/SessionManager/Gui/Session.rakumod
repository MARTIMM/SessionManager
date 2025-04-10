use v6.d;

use NativeCall;

use SessionManager::Variables;
use SessionManager::Config;
use SessionManager::Gui::ButtonCommand;

#use Gnome::Gtk4::ApplicationWindow:api<2>;
use Gnome::Gtk4::Box:api<2>;
use Gnome::Gtk4::Button:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Picture:api<2>;
use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::Frame:api<2>;
use Gnome::Gtk4::T-enums:api<2>;
use Gnome::Gtk4::Overlay:api<2>;
#use Gnome::Gtk4::PopoverMenu:api<2>;
#use Gnome::Gtk4::ScrolledWindow:api<2>;

#use Gnome::GdkPixbuf::Pixbuf:api<2>;
#use Gnome::Gdk4::Texture:api<2>;

use Gnome::Glib::N-Error:api<2>;
use Gnome::Glib::T-error:api<2>;

use Gnome::N::N-Object:api<2>;

#use Digest::SHA256::Native;


#-------------------------------------------------------------------------------
unit class SessionManager::Gui::Session:auth<github:MARTIMM>;
#also is Gnome::Gtk4::Overlay;

constant Box = Gnome::Gtk4::Box;
constant Grid = Gnome::Gtk4::Grid;
#constant ApplicationWindow = Gnome::Gtk4::ApplicationWindow;
#constant ScrolledWindow = Gnome::Gtk4::ScrolledWindow;
constant Button = Gnome::Gtk4::Button;
constant Label = Gnome::Gtk4::Label;
constant Picture = Gnome::Gtk4::Picture;
constant Frame = Gnome::Gtk4::Frame;
constant Overlay = Gnome::Gtk4::Overlay;

#constant Pixbuf = Gnome::GdkPixbuf::Pixbuf;
#constant Texture = Gnome::Gdk4::Texture;

has Str $!session-name;
has Hash $!session;

#-------------------------------------------------------------------------------
submethod BUILD ( Str:D :$!session-name, Hash:D :$!session ) { }

#-------------------------------------------------------------------------------
method session-button ( --> Overlay ) {

  my SessionManager::Config $config .= instance;
  my SessionManager::Variables $v .= instance;
#  $config.set-css( self.get-style-context, 'session-toolbar');

  my Str $title = "Session\n$!session<title>";
  my Str $picture-file = $config.set-path(
    $v.substitute-vars($!session<icon> // "$*images/$!session-name/0.png")
  );
note "$?LINE $picture-file, ", $picture-file.IO ~~ :r;

  my Picture $picture .= new-picture;
  with $picture {
    .set-filename($picture-file);
    my Int ( $w, $h) = $config.get-icon-size;
    .set-size-request( $w, -1);

    .set-margin-top(0);
    .set-margin-bottom(0);
    .set-margin-start(0);
    .set-margin-end(0);
    #.set-hexpand(True);
#    .set-vexpand-set(True);
#    .set-vexpand(True);
#    .set-valign(GTK_ALIGN_FILL);
  }

  with my Button $button .= new-button {
    .set-child($picture);
    .set-tooltip-text($!session<title>);
    $config.set-css( .get-style-context, 'session-toolbar-button');
    .register-signal(
      self, 'session-actions', 'clicked', :$!session-name, :$!session
    );
  }

  my Overlay $overlay .= new-overlay;
  $overlay.set-child($button);
#  $overlay.set-size-request($config.get-icon-size);

  my Str $overlay-icon = $config.set-path(
    $v.substitute-vars($!session<over> // "$*images/$!session-name/o0.png")
  );
note "$?LINE $overlay-icon, ", $overlay-icon.IO ~~ :r;
  if ? $overlay-icon.IO.r {
    $picture .= new-for-paintable(
      SessionManager::Gui::ButtonCommand.set-texture($overlay-icon)
    );

    with $picture {
      $overlay.add-overlay($picture);
      .set-halign(GTK_ALIGN_END);
      .set-valign(GTK_ALIGN_END);

      $config.set-css( .get-style-context, 'overlay-pic');
    }
  }

  $overlay
}


=finish

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


#-------------------------------------------------------------------------------
submethod BUILD ( Str:D :$!session-name, Hash:D :$!session ) {

  my SessionManager::Config $config .= instance;
  $config.set-css( self.get-style-context, 'session-toolbar');

  my SessionManager::Variables $v .= instance;
  my Str $title = "Session\n$!session<title>";
  my Str $picture-file = $config.set-path(
    $v.substitute-vars($!session<icon> // "$*images/$!session-name/0.png")
  );
note "$?LINE $picture-file, ", $picture-file.IO ~~ :r;

  my Picture $picture .= new-picture;
  with $picture {
    .set-filename($picture-file);
    .set-size-request($config.get-icon-size);

    .set-margin-top(0);
    .set-margin-bottom(0);
    .set-margin-start(0);
    .set-margin-end(0);
  }

  with my Button $button .= new-button {
    .set-child($picture);
    .set-tooltip-text($!session<title>);
    $config.set-css( .get-style-context, 'session-toolbar-button');
    .register-signal(
      self, 'session-actions', 'clicked', :$!session-name, :$!session
    );
  }

#  my Overlay $overlay .= new-overlay;
  self.set-child($button);

  my Str $overlay-icon = $config.set-path(
    $v.substitute-vars($!session<over> // "$*images/$!session-name/o0.png")
  );
note "$?LINE $overlay-icon, ", $overlay-icon.IO ~~ :r;
  if ? $overlay-icon.IO.r {
    $picture .= new-for-paintable(self.set-texture($overlay-icon));
    with $picture {
      self.add-overlay($picture);
      .set-halign(GTK_ALIGN_END);
      .set-valign(GTK_ALIGN_END);

      $config.set-css( .get-style-context, 'overlay-pic');
    }
  }
}

=finish



SessionManager::Gui::CreateButtonCommand

