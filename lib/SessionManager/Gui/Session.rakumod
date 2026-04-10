use v6.d;

use NativeCall;

use GnomeTools::Gtk::Theming;

use SessionManager::Variables;
use SessionManager::Config;
use SessionManager::RunActionCommand;
use SessionManager::Command;

use Gnome::Gtk4::Window:api<2>;
use Gnome::Gtk4::Widget:api<2>;
use Gnome::Gtk4::Box:api<2>;
use Gnome::Gtk4::Button:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Picture:api<2>;
use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::T-enums:api<2>;
use Gnome::Gtk4::Overlay:api<2>;
use Gnome::Gtk4::ScrolledWindow:api<2>;
use Gnome::Gtk4::TextView:api<2>;
use Gnome::Gtk4::TextBuffer:api<2>;

use Gnome::GdkPixbuf::Pixbuf:api<2>;
use Gnome::Gdk4::Texture:api<2>;

#use Gnome::Glib::N-Error:api<2>;
use Gnome::Glib::T-error:api<2>;
use Gnome::Glib::N-MainLoop:api<2>;
use Gnome::Glib::N-MainContext:api<2>;

use Gnome::N::N-Object:api<2>;

#-------------------------------------------------------------------------------
unit class SessionManager::Gui::Session:auth<github:MARTIMM>;

constant Window = Gnome::Gtk4::Window;
constant Widget = Gnome::Gtk4::Widget;
constant Box = Gnome::Gtk4::Box;
constant Grid = Gnome::Gtk4::Grid;
constant ScrolledWindow = Gnome::Gtk4::ScrolledWindow;
constant TextView = Gnome::Gtk4::TextView;
constant TextBuffer = Gnome::Gtk4::TextBuffer;
constant Button = Gnome::Gtk4::Button;
constant Label = Gnome::Gtk4::Label;
constant Picture = Gnome::Gtk4::Picture;
constant Overlay = Gnome::Gtk4::Overlay;

constant Pixbuf = Gnome::GdkPixbuf::Pixbuf;
constant Texture = Gnome::Gdk4::Texture;

has Str $!session-id;
has Hash $!manage-session;
has Grid $!session-manager-box;

has GnomeTools::Gtk::Theming $!theme;

#-------------------------------------------------------------------------------
submethod BUILD (
  Str:D :$!session-id, Hash:D :$!manage-session,
  Grid :$!session-manager-box, #Mu :$!app-window
) {
  $!theme .= new;
}

#-------------------------------------------------------------------------------
=begin pod
=head2 session-button
Create a session button. The button is placed in the toolbar.

=end pod
method session-button ( --> Widget ) {

  my Widget $widget;
  my SessionManager::Config $config .= instance;

  if $*legacy {
    $widget = self.legacy-button('session-actions');
  }

  else {
    with my Button $button .= new-button {
      $!theme.add-css-class( $button, 'session-button');
      .set-label($!manage-session<title>);
      .register-signal( self, 'session-actions', 'clicked');
    }

    $widget = $button;
  }

  $widget
}

#-------------------------------------------------------------------------------
# Session button pressed to show the action buttons in groups
method session-actions ( ) {
  # Cleanup previous action boxes, start at the deepest level
  my SessionManager::Config $config .= instance;
  for 10...1 -> $x {
    if $*legacy {
      if $!session-manager-box.get-child-at( 0, $x) {
        $!session-manager-box.remove-row($x);
      }
    }

    else {
      if $!session-manager-box.get-child-at( $x, 0) {
        $!session-manager-box.remove-column($x);
      }
    }
  }

  # Maximum of 10 levels. Originally started from 0, now 1.
  for 1..10 -> $level {
    last unless $!manage-session{"group$level"}:exists;

    my GtkOrientation $orientation =
       $*legacy ?? GTK_ORIENTATION_HORIZONTAL !! GTK_ORIENTATION_VERTICAL;
    my Box $session-buttons .= new-box( $orientation, 20);

    for @($!manage-session{"group$level"}<actions>) -> $id {
      my SessionManager::Command $command =
        SessionManager::RunActionCommand.new(:$id);
      my Widget $widget;
      if $*legacy {
        $widget = self.legacy-button(
          'setup-run', :$id, :$command, :level($level - 1)
        );
      }

      else {
        $widget = Button.new-button; #with-label($command.tooltip);
        self.set-box-widget(
          $widget, $command.tooltip // '-', $command.overlay-picture
        );
        $widget.register-signal( self, 'setup-run', 'clicked', :$id, :$command);
        $!theme.add-css-class( $widget, 'session-action-button');
      }

      $session-buttons.append($widget);
    }

    # Add session actions group
    if $*legacy {
      $!session-manager-box.attach( $session-buttons, 0, $level, 1, 1);
    }

    else {
      $!session-manager-box.attach( $session-buttons, $level, 0, 1, 1);
    }
  }
}

#-------------------------------------------------------------------------------
method setup-run ( Str:D :$id, SessionManager::Command:D :$command ) {

  my Tap $tap;
  my Window $window;

  if $command.cmd-logging {
    my SessionManager::Config $config .= instance;
    my TextBuffer() $text-buffer;
    my TextView $textview .= new-textview;
    $textview.set-wrap-mode(GTK_WRAP_WORD);

  #note "$?LINE $*THREAD.id()";
    with my ScrolledWindow $scrolled-window .= new-scrolledwindow {
      .set-child($textview);
    }

    with $window .= new-window {
      .set-title($command.tooltip);
      .set-child($scrolled-window);
      .set-default-size($config.get-log-window-size);
      .present;
    }

    $text-buffer = $textview.get-buffer;
    my Int $buffer-end = 0;
    $tap = $command.tap(
      -> $txt {
  #      "$?LINE $*THREAD.id(), $txt".printf;
        $text-buffer.insert-at-cursor( $txt, $txt.chars);
        $buffer-end += $txt.chars;
      },
      :done({ say "Supply is done" }),
      :quit( -> $ex { say "Supply finished with error $ex" }),
    );
  }

  $command.execute;

  if $command.cmd-logging {
    my Gnome::Glib::N-MainLoop $main-loop .= new-mainloop( N-Object, True);
    my Gnome::Glib::N-MainContext() $main-context = $main-loop.get-context;
    while $command.running {
  #    $*ERR.print('.');
  #    $*ERR.flush;

      while $main-context.pending {
        $main-context.iteration(False);
      }

      sleep 0.5;
    }

    sleep $command.cmd-finish-wait;
    $window.destroy;

    $tap.close;
  }

  note 'Finished';
}

#-------------------------------------------------------------------------------
# Create a widget with an image, an icon on the left, and text, left justified
# in a horizontal box
method set-box-widget ( Button $button, Str $label-text, Str $image-path ) {
  # No type; could be a Box or a Label
  my $widget;

  sub justify-left-label ( --> Label ) {
    with my Label $label .= new-label {
      .set-text($label-text);
#      .set-margin-top(0);
#      .set-margin-bottom(30);
      .set-margin-start(10);
#      .set-margin-end(30);
#      .set-hexpand-set(True);
#      .set-hexpand(True);
      .set-halign(GTK_ALIGN_START);
#      .set-vexpand-set(True);
#      .set-vexpand(True);
#      .set-valign(GTK_ALIGN_FILL);
    }

    $label
  }

  my Str $ipath;
  if ?$image-path and $image-path.IO.r {
    $ipath = $image-path;
  }
  
  else {
    $ipath = $*config-directory ~ '/Pictures/no-icon.png';
    $ipath = '' unless $ipath.IO.r;
  }

  if ? $ipath {
    my $err = CArray[N-Error].new(N-Error);
    my Gnome::GdkPixbuf::Pixbuf $gdkpixbuf .= new-from-file-at-size(
      $ipath, 64, 64, $err
    );

    my Picture $picture .= new-for-pixbuf($gdkpixbuf);

#`{{
    with my Label $strut .= new-label {
      .set-text('');
      .set-hexpand(True);
    }
}}

    with $widget = Box.new-box( GTK_ORIENTATION_HORIZONTAL, 5) {
      .append($picture);
      .append(justify-left-label);
#      .append($strut);
    }
  }

  else {
    $widget = justify-left-label;
  }

  $button.set-child($widget);
}

#-------------------------------------------------------------------------------
method legacy-button (
  Str $method, Int :$level = -1,
  SessionManager::Command :$command, *%options --> Overlay
) {
  my SessionManager::Config $config .= instance;
  my SessionManager::Variables $variables .= new;

  my Str $title = "Session\n$!manage-session<title>";
  my Str $picture-file;
  my Str $overlay-icon;
  my Str $tooltip-text;
  if $level == -1 {
    $picture-file = $variables.substitute-vars($!manage-session<icon> // '');
    $overlay-icon = $variables.substitute-vars($!manage-session<over> // '');
    $tooltip-text = $variables.substitute-vars($!manage-session<title> // '');
  }

  else {
    $picture-file = $variables.substitute-vars($command.picture // '');
    $overlay-icon = $variables.substitute-vars($command.overlay-picture // '');
    $tooltip-text = $variables.substitute-vars($command.tooltip // '');
  }

  my Picture $picture .= new-picture;
  if ?$picture-file and $picture-file.IO ~~ :r {
    with $picture {
      .set-filename($picture-file);
      my Int ( $w, $h) = $config.get-icon-size;
      .set-size-request( $w, $h);

      .set-margin-top(0);
      .set-margin-bottom(0);
      .set-margin-start(0);
      .set-margin-end(0);
      .set-vexpand-set(True);
      .set-vexpand(True);
    }
  }

  with my Button $button .= new-button {
    .set-child($picture);
    .set-tooltip-text($tooltip-text);
    $!theme.add-css-class( $button, 'session-toolbar-button');
    .register-signal( self, $method, 'clicked', :$command, |%options);
  }

  my Overlay $overlay .= new-overlay;
  $overlay.set-child($button);
  if ?$overlay-icon and $overlay-icon.IO ~~ :r {
    $picture .= new-for-paintable(self.set-texture($overlay-icon));

    with $picture {
      $overlay.add-overlay($picture);
      .set-halign(GTK_ALIGN_END);
      .set-valign(GTK_ALIGN_END);

      $!theme.add-css-class( $picture, 'overlay-pic');
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
