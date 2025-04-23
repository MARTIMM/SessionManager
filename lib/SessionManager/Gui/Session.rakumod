use v6.d;

use NativeCall;

use SessionManager::Variables;
use SessionManager::Config;
use SessionManager::RunActionCommand;
use SessionManager::Command;

#use Gnome::Gtk4::ApplicationWindow:api<2>;
use Gnome::Gtk4::Window:api<2>;
use Gnome::Gtk4::Box:api<2>;
use Gnome::Gtk4::Button:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Picture:api<2>;
use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::Frame:api<2>;
use Gnome::Gtk4::T-enums:api<2>;
#use Gnome::Gtk4::Overlay:api<2>;
#use Gnome::Gtk4::PopoverMenu:api<2>;
use Gnome::Gtk4::ScrolledWindow:api<2>;
use Gnome::Gtk4::TextView:api<2>;
use Gnome::Gtk4::TextBuffer:api<2>;
#use Gnome::Gtk4::N-TextIter:api<2>;
#use Gnome::Gtk4::T-textiter:api<2>;

#use Gnome::GdkPixbuf::Pixbuf:api<2>;
#use Gnome::Gdk4::Texture:api<2>;

use Gnome::Glib::N-Error:api<2>;
use Gnome::Glib::T-error:api<2>;
use Gnome::Glib::N-MainLoop:api<2>;
use Gnome::Glib::N-MainContext:api<2>;
#use Gnome::Glib::T-main:api<2>;

use Gnome::N::N-Object:api<2>;

#use Digest::SHA256::Native;


#-------------------------------------------------------------------------------
unit class SessionManager::Gui::Session:auth<github:MARTIMM>;
#also is Gnome::Gtk4::Overlay;

constant Window = Gnome::Gtk4::Window;
constant Box = Gnome::Gtk4::Box;
constant Grid = Gnome::Gtk4::Grid;
#constant ApplicationWindow = Gnome::Gtk4::ApplicationWindow;
constant ScrolledWindow = Gnome::Gtk4::ScrolledWindow;
constant TextView = Gnome::Gtk4::TextView;
constant TextBuffer = Gnome::Gtk4::TextBuffer;
constant Button = Gnome::Gtk4::Button;
constant Label = Gnome::Gtk4::Label;
constant Picture = Gnome::Gtk4::Picture;
constant Frame = Gnome::Gtk4::Frame;
#constant Overlay = Gnome::Gtk4::Overlay;

#constant Pixbuf = Gnome::GdkPixbuf::Pixbuf;
#constant Texture = Gnome::Gdk4::Texture;

has Str $!session-name;
has Hash $!manage-session;

#-------------------------------------------------------------------------------
submethod BUILD ( Str:D :$!session-name, Hash:D :$!manage-session ) { }

#-------------------------------------------------------------------------------
method session-button ( --> Button ) {

  my SessionManager::Config $config .= instance;
#  my SessionManager::Variables $v .= instance;
#  $config.set-css( self.get-style-context, 'session-toolbar');

  with my Button $button .= new-button {
    .set-label($!manage-session<title>);
#    .set-child($picture);
#    .set-tooltip-text("Session\n$!manage-session<title>");
#    $config.set-css( .get-style-context, 'session-toolbar-button');

    .register-signal(
      self, 'session-actions', 'clicked',
      :$!session-name, :$!manage-session
    );
  }

  $button
}

#-------------------------------------------------------------------------------
# Session button pressed to show the action buttons in groups
method session-actions (
  Str :$session-name, Hash:D :$manage-session
) {
#note "\n\n$?LINE $session-name, $manage-session.gist()";

  my Grid $sessions .= new-grid;

  my SessionManager::Config $config .= instance;
  with my Frame $session-frame .= new-frame('') {
    $config.set-css( .get-style-context, 'session-frame');
    .set-margin-top(0);
    .set-margin-bottom(0);
    .set-margin-start(0);
    .set-margin-end(0);

    # Put a text upfront the  list of actions when specified
    # CSS is used to rotate the text
    my Label() $label = .get-label-widget;
    $config.set-css( $label.get-style-context, 'session-frame-label');
    .set-label-widget(
      self.label-widget( $session-name, $manage-session, :!show-button)
    );
  }

  # The first row is for shortcuts and sessions. The second for
  # actions of a session
  $sessions.remove-row(1) if $sessions.get-child-at( 0, 1);
  $sessions.attach( $session-frame, 0, 1, 1, 1);

  my Box $session-levels .= new-box( GTK_ORIENTATION_HORIZONTAL, 1);
  $session-frame.set-child($session-levels);


  # Maximum of 10 levels. Originally started from 0, now 1.
  for 1..10 -> $level {
#    last unless $config.has-actions-level( $session-name, $level);
    last unless $manage-session{"group$level"}:exists;

#    my Box $session-buttons .= new-box( GTK_ORIENTATION_VERTICAL, 1);

    with my Box $session-buttons .= new-box( GTK_ORIENTATION_VERTICAL, 1) {
      .set-spacing(20);
#      .set-margin-top(0);
#      .set-margin-bottom(30);
#      .set-margin-start(30);
#      .set-margin-end(30);
      .set-hexpand-set(True);
      .set-hexpand(True);
      .set-vexpand-set(True);
      .set-vexpand(True);
#      .set-valign(GTK_ALIGN_FILL);

#`{{
      # Get a title for the session group
      my Str $gtitle = $config.get-session-group-title( $session-name, $level);
      with my Label $glabel .= new-label {
        $session-buttons.append($glabel);
        .set-text($gtitle // '');
        .allocate( 200, 30, -1, N-Object);
        $config.set-css( $glabel.get-style-context, 'group-session-label');
      }
}}

      my UInt $count = 0;
      for @($manage-session{"group$level"}<actions>) -> $id {

        my SessionManager::Command $command =
          SessionManager::RunActionCommand.new(:$id);
#note "$?LINE $command.tooltip()";
        my Button $button .= new-with-label($command.tooltip);
        $button.register-signal( self, 'setup-run', 'clicked', :$id, :$command);
        .append($button);

#`{{
        my SessionManager::Gui::CommandButton $button-command .= new(:$id);
        .append($button-command.make-button(
            $session-name, $level - 1, $count
          )
        );
}}
        $count++;
      }

#`{{
      # Clear first
      $!action-data{$session-name} = [];
      my UInt $count = 0;
      for $config.get-session-actions( $session-name, $level) -> $action {
        # Originally the level was from 0 .. ^n, now 1 .. n
        my Overlay $overlay = self.action-button(
          self.process-action( $session-name, $action, $level-1, $count)
        );

        .append($overlay);

        $count++;
      }
}}
    }

    $session-levels.append($session-buttons);
  }

  with my Window $window .= new-window {
    .set-child($sessions);
    .set-title($manage-session<title>);
#      .set-default-size($config.get-window-size);
    .present;
  }
}

#-------------------------------------------------------------------------------
method setup-run ( Str:D :$id, SessionManager::Command:D :$command ) {

  my SessionManager::Config $config .= instance;

#note "$?LINE $*THREAD.id()";
  with my ScrolledWindow $scrolled-window .= new-scrolledwindow {
    .set-child($textview);
  }

  with my Window $window .= new-window {
    .set-title($command.tooltip);
    .set-child($scrolled-window);
    .set-default-size($config.get-window-size);
    .present;
  }

  my TextBuffer() $text-buffer;
  my TextView $textview .= new-textview;
  $text-buffer = $textview.get-buffer;
  my Int $buffer-end = 0;
  my $tap = $command.tap(
    -> $txt {
#      "$?LINE $*THREAD.id(), $txt".printf;
      $text-buffer.insert-at-cursor( $txt, $txt.chars);
      $buffer-end += $txt.chars;
    },
    :done({ say "Supply is done" }),
    :quit( -> $ex { say "Supply finished with error $ex" }),
  );

  $command.execute;

  my Gnome::Glib::N-MainLoop $main-loop .= new-mainloop( N-Object, True);
  my Gnome::Glib::N-MainContext() $main-context = $main-loop.get-context;
  while $command.running {
    $*ERR.print('.');
    $*ERR.flush;
    sleep 0.5;

    while $main-context.pending {
      $main-context.iteration(False);
    }
  }

  $tap.close;
  note 'Finished';
}

#-------------------------------------------------------------------------------
method label-widget (
  Str $session-name, Hash:D $manage-session, Bool :$show-button --> Mu
) {

  my SessionManager::Config $config .= instance;
  my Str $session-title = $manage-session<title>;
  my Label $label .= new-label;
  $label.set-text($session-title);

  $config.set-css( $label.get-style-context, 'session-frame-label');
#`{{
  if $show-button and $!config.run-all-actions($session-name) {
    my Str $png-file = [~] DATA_DIR, '/Images/fastforward.png>';
    my Box $label-widget .= new-box( GTK_ORIENTATION_HORIZONTAL, 5);

    my Picture $picture .= new-picture;
    $picture.set-filename(%?RESOURCES<fastforward.png>.IO.Str);
    $picture.set-size-request( 32, 32);

    my Button $run-all-actions .= new-button;
    $run-all-actions.set-child($picture);
    $run-all-actions.register-signal(
      self, 'run-all-actions', 'clicked', :$session-name
    );

    $label-widget.append($run-all-actions);
    $label-widget.append($label);

    $label-widget
  }

  else {
}}
    $label
#  }
}




=finish
#-------------------------------------------------------------------------------
method session-button ( --> Overlay ) {

  my SessionManager::Config $config .= instance;
  my SessionManager::Variables $v .= instance;
#  $config.set-css( self.get-style-context, 'session-toolbar');

  my Str $title = "Session\n$!manage-session<title>";
  my Str $picture-file = $config.set-path(
    $v.substitute-vars($!manage-session<icon> // "$*images/$!session-name/0.png")
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
    .set-tooltip-text($!manage-session<title>);
    $config.set-css( .get-style-context, 'session-toolbar-button');
    .register-signal(
      self, 'session-actions', 'clicked', :$!session-name, :$!manage-session
    );
  }

  my Overlay $overlay .= new-overlay;
  $overlay.set-child($button);
#  $overlay.set-size-request($config.get-icon-size);

  my Str $overlay-icon = $config.set-path(
    $v.substitute-vars($!manage-session<over> // "$*images/$!session-name/o0.png")
  );
note "$?LINE $overlay-icon, ", $overlay-icon.IO ~~ :r;
  if ? $overlay-icon.IO.r {
    $picture .= new-for-paintable(
      SessionManager::Gui::CommandButton.set-texture($overlay-icon)
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
submethod BUILD ( Str:D :$!session-name, Hash:D :$!manage-session ) {

  my SessionManager::Config $config .= instance;
  $config.set-css( self.get-style-context, 'session-toolbar');

  my SessionManager::Variables $v .= instance;
  my Str $title = "Session\n$!manage-session<title>";
  my Str $picture-file = $config.set-path(
    $v.substitute-vars($!manage-session<icon> // "$*images/$!session-name/0.png")
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
    .set-tooltip-text($!manage-session<title>);
    $config.set-css( .get-style-context, 'session-toolbar-button');
    .register-signal(
      self, 'session-actions', 'clicked', :$!session-name, :$!manage-session
    );
  }

#  my Overlay $overlay .= new-overlay;
  self.set-child($button);

  my Str $overlay-icon = $config.set-path(
    $v.substitute-vars($!manage-session<over> // "$*images/$!session-name/o0.png")
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



SessionManager::Gui::CommandButton

