use v6.d;

use NativeCall;

use SessionManager::Config;
use SessionManager::Gui::Session;

#use Gnome::Gtk4::ApplicationWindow:api<2>;
#use Gnome::Gtk4::ScrolledWindow:api<2>;
use Gnome::Gtk4::Box:api<2>;
use Gnome::Gtk4::Button:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Picture:api<2>;
use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::Frame:api<2>;
use Gnome::Gtk4::T-enums:api<2>;
use Gnome::Gtk4::Overlay:api<2>;
#use Gnome::Gtk4::PopoverMenu:api<2>;

use Gnome::GdkPixbuf::Pixbuf:api<2>;
use Gnome::Gdk4::Texture:api<2>;

use Gnome::Glib::N-Error:api<2>;
use Gnome::Glib::T-error:api<2>;

use Gnome::N::N-Object:api<2>;

use GnomeTools::Gtk::Theming;

#use Digest::SHA256::Native;

#-------------------------------------------------------------------------------
#`{{
}}

#-------------------------------------------------------------------------------
unit class SessionManager::Gui::Toolbar:auth<github:MARTIMM>;
also is Gnome::Gtk4::Box;

constant Box = Gnome::Gtk4::Box;
constant Grid = Gnome::Gtk4::Grid;
#constant ApplicationWindow = Gnome::Gtk4::ApplicationWindow;
#constant ScrolledWindow = Gnome::Gtk4::ScrolledWindow;
constant Button = Gnome::Gtk4::Button;
constant Label = Gnome::Gtk4::Label;
constant Picture = Gnome::Gtk4::Picture;
constant Frame = Gnome::Gtk4::Frame;
constant Overlay = Gnome::Gtk4::Overlay;

constant Pixbuf = Gnome::GdkPixbuf::Pixbuf;
constant Texture = Gnome::Gdk4::Texture;

has GnomeTools::Gtk::Theming $!theme;

#-------------------------------------------------------------------------------
submethod BUILD ( Grid :$session-manager-box, Mu :$app-window ) {

  my SessionManager::Config $config .= instance;
  my GtkOrientation $orientation =
      $config.legacy ?? GTK_ORIENTATION_HORIZONTAL !! GTK_ORIENTATION_VERTICAL;

  with self {
    .set-orientation($orientation);
    $!theme.add-css-class( self, 'session-toolbar');
    .set-spacing(10);
#    .set-vexpand-set(True);
#    .set-vexpand(True);
#    .set-valign(GTK_ALIGN_FILL);
  }

  my Hash $sessions = $config.get-sessions;
  for $sessions.keys.sort -> $session-name {
    my SessionManager::Gui::Session $session .= new(
      :$session-name, :manage-session($sessions{$session-name}),
      :$session-manager-box, :$app-window
    );

    self.append($session.session-button);
  }

  $!theme .= new;

#`{{
  # Then a series of session buttons
  for $!config.get-sessions -> $session-name {
    my Str $session-title =
      "Session\n" ~ $!config.get-session-title($session-name);
    my Str $picture-file =
      self.substitute-vars($!config.get-session-icon($session-name));

    with my Picture $picture .= new-picture {
      .set-filename($!config.set-path($picture-file));
      .set-size-request($!config.get-icon-size);

      .set-margin-top(0);
      .set-margin-bottom(0);
      .set-margin-start(0);
      .set-margin-end(0);
    }

    with my Button $button .= new-button {
      .set-child($picture);
      .set-tooltip-text($session-title);
      $!config.set-css( .get-style-context, 'session-toolbar-button');
      .register-signal(
        self, 'session-actions', 'clicked', :$session-name, :$sessions
      );
    }

    my Overlay $overlay .= new-overlay;
    $overlay.set-child($button);

    my Str $overlay-icon = $!config.set-path(
      self.substitute-vars($!config.get-session-overlay-icon($session-name))
    );

#note "$?LINE $overlay-icon, ", $overlay-icon.IO ~~ :e;
    if ? $overlay-icon.IO.r {
      with my Picture $overlay-pic .= new-for-paintable(
        self.set-texture($overlay-icon)
      ) {
        $overlay.add-overlay($overlay-pic);
        .set-halign(GTK_ALIGN_END);
        .set-valign(GTK_ALIGN_END);

        $!config.set-css( .get-style-context, 'overlay-pic');
      }
    }

    $toolbar.append($overlay);
  }
}}

}


=finish
#-------------------------------------------------------------------------------
submethod BUILD ( ) {

  with my Box $toolbar .= new-box( GTK_ORIENTATION_HORIZONTAL, 1) {
    $!config.set-css( .get-style-context, 'session-toolbar');
    .set-spacing(10);
  }

  # Prepare. First a series of direct action buttons - shortcuts
  $!action-data<toolbar> = [];
  my $count = 0;

  for $!config.get-toolbar-actions -> Hash $action {
    my Hash $action-data = self.process-action( 'toolbar', $action, 0, $count);
#note "\n\n$?LINE ", $!action-data.gist;

    $action-data<tooltip> = "Run\n$action-data<tooltip>";

    with my Picture $picture .= new-picture {
      .set-filename($action-data<picture-file>);
      .set-size-request($!config.get-icon-size);

      .set-margin-top(0);
      .set-margin-bottom(0);
      .set-margin-start(0);
      .set-margin-end(0);
    }

    my Overlay $overlay = self.action-button($action-data);
    if $action-data<overlay-picture-file>:exists and
      $action-data<overlay-picture-file>.IO.r
    {
      with my Picture $overlay-pic .= new-for-paintable(
        self.set-texture($action-data<overlay-picture-file>)
      ) {
        $overlay.add-overlay($overlay-pic);
        .set-halign(GTK_ALIGN_END);
        .set-valign(GTK_ALIGN_END);

        $!config.set-css( .get-style-context, 'overlay-pic');
      }
    }

    $toolbar.append($overlay);
    $count++;
  }

  # Then a series of session buttons
  for $!config.get-sessions -> $session-name {
    my Str $session-title =
      "Session\n" ~ $!config.get-session-title($session-name);
    my Str $picture-file =
      self.substitute-vars($!config.get-session-icon($session-name));

    with my Picture $picture .= new-picture {
      .set-filename($!config.set-path($picture-file));
      .set-size-request($!config.get-icon-size);

      .set-margin-top(0);
      .set-margin-bottom(0);
      .set-margin-start(0);
      .set-margin-end(0);
    }

    with my Button $button .= new-button {
      .set-child($picture);
      .set-tooltip-text($session-title);
      $!config.set-css( .get-style-context, 'session-toolbar-button');
      .register-signal(
        self, 'session-actions', 'clicked', :$session-name, :$sessions
      );
    }

    my Overlay $overlay .= new-overlay;
    $overlay.set-child($button);

    my Str $overlay-icon = $!config.set-path(
      self.substitute-vars($!config.get-session-overlay-icon($session-name))
    );

#note "$?LINE $overlay-icon, ", $overlay-icon.IO ~~ :e;
    if ? $overlay-icon.IO.r {
      with my Picture $overlay-pic .= new-for-paintable(
        self.set-texture($overlay-icon)
      ) {
        $overlay.add-overlay($overlay-pic);
        .set-halign(GTK_ALIGN_END);
        .set-valign(GTK_ALIGN_END);

        $!config.set-css( .get-style-context, 'overlay-pic');
      }
    }

    $toolbar.append($overlay);
  }
#`{{
  with my ScrolledWindow $window .= new-scrolledwindow {
    .set-child($toolbar);
    .set-size-request($!config.get-window-size);
#    .set-default-size($!config.get-window-size);
  }

  $window
}}

  $toolbar
}