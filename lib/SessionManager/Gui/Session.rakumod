use v6.d;

use NativeCall;

use GnomeTools::Gtk::Theming;

use SessionManager::Variables;
use SessionManager::Config;
use SessionManager::RunActionCommand;
use SessionManager::Command;

#use Gnome::Gtk4::ApplicationWindow:api<2>;
use Gnome::Gtk4::Window:api<2>;
use Gnome::Gtk4::Widget:api<2>;
use Gnome::Gtk4::Box:api<2>;
use Gnome::Gtk4::Button:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Picture:api<2>;
use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::Frame:api<2>;
use Gnome::Gtk4::T-enums:api<2>;
use Gnome::Gtk4::Overlay:api<2>;
#use Gnome::Gtk4::PopoverMenu:api<2>;
use Gnome::Gtk4::ScrolledWindow:api<2>;
use Gnome::Gtk4::TextView:api<2>;
use Gnome::Gtk4::TextBuffer:api<2>;
#use Gnome::Gtk4::N-TextIter:api<2>;
#use Gnome::Gtk4::T-textiter:api<2>;

use Gnome::GdkPixbuf::Pixbuf:api<2>;
use Gnome::Gdk4::Texture:api<2>;

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
constant Widget = Gnome::Gtk4::Widget;
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
constant Overlay = Gnome::Gtk4::Overlay;

constant Pixbuf = Gnome::GdkPixbuf::Pixbuf;
constant Texture = Gnome::Gdk4::Texture;

has Str $!session-id;
has Hash $!manage-session;
has Grid $!session-manager-box;

has GnomeTools::Gtk::Theming $!theme;

has Mu $!app-window;

#-------------------------------------------------------------------------------
submethod BUILD (
  Str:D :$!session-id, Hash:D :$!manage-session,
  Grid :$!session-manager-box, Mu :$!app-window
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
#  my SessionManager::Variables $v .= new;
#  $!theme.add-css-class( self, 'session-toolbar');

  if $*legacy {
    $widget = self.legacy-button(
      'session-actions', :$!session-id, :$!manage-session
    );
  }

  else {
    with my Button $button .= new-button {
      $!theme.add-css-class( $button, 'session-button');
      .set-label($!manage-session<title>);
  #    .set-child($picture);
  #    .set-tooltip-text("Session\n$!manage-session<title>");
      .register-signal(
        self, 'session-actions', 'clicked',
        :$!session-id, :$!manage-session
      );
    }

    $widget = $button;
  }

  $widget
}

#-------------------------------------------------------------------------------
# Session button pressed to show the action buttons in groups
method session-actions (
  Str :$session-name, Hash:D :$manage-session
) {
#note "\n$?LINE $session-name";
  # Cleanup previous action boxes, start at the deepest level
  my SessionManager::Config $config .= instance;
  for 10...1 -> $x {
#note "$?LINE $x, {$!session-manager-box.get-child-at( $x, 0) // '-'}";
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
#note "$?LINE $config.get-window-size(), ", ? $!app-window;
    $!app-window.set-default-size($config.get-window-size) if ? $!app-window;

#    else {
#      last;
#    }
  }

#  my Grid $sessions .= new-grid;


#`{{
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
}}

  # The first row is for shortcuts and sessions. The second for
  # actions of a session
#  $sessions.remove-row(1) if $sessions.get-child-at( 0, 1);
#  $sessions.attach( $session-frame, 0, 1, 1, 1);
#  my Box $session-levels .= new-box( GTK_ORIENTATION_HORIZONTAL, 1);
#  $session-frame.set-child($session-levels);


  # Maximum of 10 levels. Originally started from 0, now 1.
  for 1..10 -> $level {
#    last unless $config.has-actions-level( $session-name, $level);
    last unless $manage-session{"group$level"}:exists;

#    my Box $session-buttons .= new-box( GTK_ORIENTATION_VERTICAL, 1);

    my GtkOrientation $orientation =
       $*legacy ?? GTK_ORIENTATION_HORIZONTAL !! GTK_ORIENTATION_VERTICAL;
    my Box $session-buttons .= new-box( $orientation, 1);
    $session-buttons.set-spacing(20);
#      .set-margin-top(0);
#      .set-margin-bottom(30);
#      .set-margin-start(30);
#      .set-margin-end(30);
#      .set-hexpand-set(True);
#      .set-hexpand(True);
#      .set-vexpand-set(True);
#      .set-vexpand(True);
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

    for @($manage-session{"group$level"}<actions>) -> $id {

      my SessionManager::Command $command =
        SessionManager::RunActionCommand.new(:$id);
#note "$?LINE $command.tooltip()";
      my Widget $widget;
      if $*legacy {
        $widget = self.legacy-button( 'setup-run', :$id, :$command, :level($level - 1));
      }

      else {
        $widget = Button.new-button; #with-label($command.tooltip);
        self.set-box-widget(
          $widget, $command.tooltip, $command.overlay-picture
        );
        $widget.register-signal( self, 'setup-run', 'clicked', :$id, :$command);
        $!theme.add-css-class( $widget, 'session-action-button');
      }

      $session-buttons.append($widget);
#`{{
      my SessionManager::Gui::CommandButton $button-command .= new(:$id);
      .append($button-command.make-button(
          $session-name, $level - 1, $count
        )
      );
}}
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

    # Add session actions group
    if $*legacy {
      $!session-manager-box.attach( $session-buttons, 0, $level, 1, 1);
    }

    else {
      $!session-manager-box.attach( $session-buttons, $level, 0, 1, 1);
    }
#    $session-levels.append($session-buttons);
  }

#`{{
  with my Window $window .= new-window {
    .set-child($sessions);
    .set-title($manage-session<title>);
#      .set-default-size($config.get-window-size);
    .present;
  }
}}
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

#`{{
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
}}

#-------------------------------------------------------------------------------
# Create a widget with an image, an icon on the left, and text, left justified
# in a horizontal box
method set-box-widget ( Button $button, Str $label-text, Str $image-path ) {
  # No type; could be a Box or a Label
  my $widget;
  #if $image-path.IO ~~ :r {
#note "$?LINE set-box-widget {$image-path // '-'}";
  if ? $image-path {
    my Picture $picture .= new-picture;
    $picture.set-filename($image-path);
    $picture.set-size-request( 64, 64);

    my Box $image-container = Box.new-box( GTK_ORIENTATION_HORIZONTAL, 0);
    $image-container.append($picture);

    my Label $label .= new-label;
    $label.set-text($label-text);

    with my Label $strut .= new-label {
      .set-text(' ');
      .set-hexpand(True);
    }

    with $widget = Box.new-box( GTK_ORIENTATION_HORIZONTAL, 5) {
      .append($image-container);
      .append($label);
      .append($strut);
    }
  }

  else {
    $widget = Label.new-label;
    $widget.set-text($label-text);
  }

  $button.set-child($widget);
}


#`{{
  $config.set-css( $label.get-style-context, 'session-frame-label');
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
    $label
#  }
}
}}




#-------------------------------------------------------------------------------
method legacy-button (
  Str $method, Int :$level = -1,
  SessionManager::Command :$command, *%options --> Overlay
) {
  my SessionManager::Config $config .= instance;
  my SessionManager::Variables $variables .= new;
#  $config.set-css( self.get-style-context, 'session-toolbar');

#  my SessionManager::Command $command = %options<command>;

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

#note "$?LINE $picture-file, $overlay-icon, $tooltip-text":

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
  #    .set-hexpand(True);
      .set-vexpand-set(True);
      .set-vexpand(True);
  #    .set-valign(GTK_ALIGN_FILL);
    }
  }

  with my Button $button .= new-button {
    .set-child($picture);
    .set-tooltip-text($tooltip-text);
    if $level == -1 {
#      .set-tooltip-text($!manage-session<title>);
    }

    else {
#      .set-tooltip-text($command.tooltip);
    }

    $!theme.add-css-class( $button, 'session-toolbar-button');
    .register-signal( self, $method, 'clicked', :$command, |%options);
  }

  my Overlay $overlay .= new-overlay;
  $overlay.set-child($button);
#  $overlay.set-size-request($config.get-icon-size);

  if $level == -1 {
  }

  else {
  }

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

=finish

#-------------------------------------------------------------------------------
submethod BUILD ( Str:D :$!session-id, Hash:D :$!manage-session ) {

  my SessionManager::Config $config .= instance;
  $config.set-css( self.get-style-context, 'session-toolbar');

  my SessionManager::Variables $v .= new;
  my Str $title = "Session\n$!manage-session<title>";
  my Str $picture-file = $config.set-path(
    $v.substitute-vars($!manage-session<icon> // "$*images/$!session-id/0.png")
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
      self, 'session-actions', 'clicked', :$!session-id, :$!manage-session
    );
  }

#  my Overlay $overlay .= new-overlay;
  self.set-child($button);

  my Str $overlay-icon = $config.set-path(
    $v.substitute-vars($!manage-session<over> // "$*images/$!session-id/o0.png")
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

