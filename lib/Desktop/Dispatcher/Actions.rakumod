
use v6.d;

use NativeCall;

use Desktop::Dispatcher::Config;

use Gnome::Gtk4::ApplicationWindow:api<2>;
use Gnome::Gtk4::Box:api<2>;
use Gnome::Gtk4::Button:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Picture:api<2>;
use Gnome::Gtk4::Frame:api<2>;
use Gnome::Gtk4::T-enums:api<2>;
use Gnome::Gtk4::Overlay:api<2>;
use Gnome::Gtk4::PopoverMenu:api<2>;

use Gnome::GdkPixbuf::Pixbuf:api<2>;

use Gnome::Glib::N-Error:api<2>;
use Gnome::Glib::T-error:api<2>;

use Gnome::N::N-Object:api<2>;

use Digest::SHA256::Native;

#-------------------------------------------------------------------------------
unit class Desktop::Dispatcher::Actions:auth<github:MARTIMM>;

has Desktop::Dispatcher::Config $!config;
has Bool $!init-config;
has Str $!shell; 
has Gnome::Gtk4::ApplicationWindow $!app-window;

#-------------------------------------------------------------------------------
submethod BUILD (
  Desktop::Dispatcher::Config:D :$!config,
  Gnome::Gtk4::ApplicationWindow :$!app-window
) {
  $!init-config = True;
  $!shell = $!config.get-shell;
}

#-------------------------------------------------------------------------------
method setup-sessions ( --> Gnome::Gtk4::Box ) {

  with my Gnome::Gtk4::Box $sessions .= new-box(GTK_ORIENTATION_VERTICAL) {
    .set-margin-top(0);
    .set-margin-bottom(0);
    .set-margin-start(0);
    .set-margin-end(0);

    .append(self.make-toolbar($sessions));
    $!config.set-css( .get-style-context, 'sessions');
  }

  $sessions
}

#-------------------------------------------------------------------------------
method make-toolbar ( Gnome::Gtk4::Box $sessions --> Gnome::Gtk4::Box ) {
  with my Gnome::Gtk4::Box $toolbar .= new-box(GTK_ORIENTATION_HORIZONTAL) {
    $!config.set-css( .get-style-context, 'session-toolbar');
    .set-spacing(10);
  }

  # First a series of direct action buttons
  my $count = 0;
  for $!config.get-toolbar-actions -> Hash $action {
    my Hash $action-data = self.process-action( :$action, :level(0), :$count);
    $action-data<tooltip> = "Run\n$action-data<tooltip>";

    with my Gnome::Gtk4::Picture $picture .= new-picture {
      .set-filename($action-data<picture-file>);
      .set-size-request($!config.get-icon-size);

      .set-margin-top(0);
      .set-margin-bottom(0);
      .set-margin-start(0);
      .set-margin-end(0);
    }

    my Gnome::Gtk4::Overlay $overlay = self.action-button($action-data);
    if $action-data<overlay-picture-file>:exists and
      $action-data<overlay-picture-file>.IO.r
    {
      # Need to use a box or resize the picture, otherwise it will
      # use up all of the overlay area if the picture is large.
      my $err = CArray[N-Error].new(N-Error);
      my Int ( $w, $h) = ($!config.get-icon-size.List X/ 3)>>.Int;
      my Gnome::GdkPixbuf::Pixbuf $gdkpixbuf .= new-from-file-at-size(
        $action-data<overlay-picture-file>, $w, $h, $err
      );

      my Gnome::Gtk4::Picture $overlay-pic;
      with $overlay-pic .= new-for-pixbuf($gdkpixbuf) {
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

    with my Gnome::Gtk4::Picture $picture .= new-picture {
      .set-filename($!config.set-path($picture-file));
      .set-size-request($!config.get-icon-size);

      .set-margin-top(0);
      .set-margin-bottom(0);
      .set-margin-start(0);
      .set-margin-end(0);
    }

    with my Gnome::Gtk4::Button $button .= new-button {
      .set-child($picture);
      .set-tooltip-text($session-title);
      $!config.set-css( .get-style-context, 'session-toolbar-button');
      .register-signal(
        self, 'session-actions', 'clicked', :$session-name, :$sessions
      );
    }

    my Gnome::Gtk4::Overlay $overlay .= new-overlay;
    $overlay.set-child($button);


    my Str $overlay-icon = self.substitute-vars(
      $!config.set-path($!config.get-session-overlay-icon($session-name))
    );

    if ? $overlay-icon.IO.r {

      my $err = CArray[N-Error].new(N-Error);
      my Int ( $w, $h) = ($!config.get-icon-size.List X/ 3)>>.Int;
      my Gnome::GdkPixbuf::Pixbuf $gdkpixbuf .= new-from-file-at-size(
        $overlay-icon, $w, $h, $err
      );

      my Gnome::Gtk4::Picture $overlay-pic;
      with $overlay-pic .= new-for-pixbuf($gdkpixbuf) {
        $overlay.add-overlay($overlay-pic);
        .set-halign(GTK_ALIGN_END);
        .set-valign(GTK_ALIGN_END);

        $!config.set-css( .get-style-context, 'overlay-pic');
      }
    }

    $toolbar.append($overlay);
  }

  $toolbar
}

#-------------------------------------------------------------------------------
method session-actions ( Str :$session-name, Gnome::Gtk4::Box :$sessions ) {
  state Gnome::Gtk4::Frame $session-frame;

  my Str $session-title = $!config.get-session-title($session-name);
  if $!init-config {
    $session-frame.clear-object if ?$session-frame;
    with $session-frame .= new-frame($session-title) {
      $!config.set-css( .get-style-context, 'session-frame');
      .set-margin-top(0);
      .set-margin-bottom(0);
      .set-margin-start(0);
      .set-margin-end(0);
      my Gnome::Gtk4::Label() $label = .get-label-widget;
      $!config.set-css( $label.get-style-context, 'session-frame-label');
    }

    $sessions.append($session-frame);
    $!init-config = False;
  }

  else {
    my Gnome::Gtk4::Label() $label = $session-frame.get-label-widget;
    $label.set-text($session-title);
  }

  my Gnome::Gtk4::Box $session-levels .= new-box(
    GTK_ORIENTATION_VERTICAL
  );
  $session-frame.set-child($session-levels);

  $!app-window.set-default-size($!config.get-window-size);
  loop ( my UInt $level = 0; $level < 5; $level++ ) {
    last unless $!config.has-actions-level( $session-name, :$level);

    my Gnome::Gtk4::Box $session-buttons .= new-box(
      GTK_ORIENTATION_HORIZONTAL
    );

    $session-levels.append($session-buttons);

    with $session-buttons {
      .set-spacing(20);
      .set-margin-top(0);
      .set-margin-bottom(30);
      .set-margin-start(30);
      .set-margin-end(30);

      my UInt $count = 0;
      for $!config.get-session-actions( $session-name, :$level) -> $action {
        my Hash $action-data =
           self.process-action( :$session-name, :$action, :$level, :$count);
        my Gnome::Gtk4::Overlay $overlay = self.action-button($action-data);
        .append($overlay);

        $count++;
      }
    }
  }
}

#-------------------------------------------------------------------------------
method process-action (
   Str :$session-name = 'toolbar', Hash :$action, UInt :$level, UInt :$count
   --> Hash
) {
  my Hash $action-data = %(
    :$session-name, :$level, :picture-file(DATA_DIR ~ '/Images/config-icon.jpg')
  );

  note "\nSession data for $session-name" if $*verbose;

  # Get tooltip text
  if ? $action<t> {
    $action-data<tooltip> = self.substitute-vars($action<t>);
    note "Set tooltip to\n  ", $action-data<tooltip>.split("\n").join("\n  ")
      if $*verbose;
  }

  # Set path to work directory
  if ? $action<p> {
    $action-data<work-dir> = self.substitute-vars($action<p>);
    note "Set workdir to $action-data<work-dir>" if $*verbose;
  }

  # Set environment
  if ? $action<e> {
    $action-data<env> = self.substitute-vars($action<e>);
    note "Set environment to $action-data<env>" if $*verbose;
  }

  # Script to run before command can run
  if ? $action<s> {
    $action-data<script> = self.substitute-vars($action<s>);
    note "Set script to\n  ", $action-data<script>.split("\n").join("\n  ")
      if $*verbose;
  }

  # Set command to run
  if ? $action<c> {
    $action-data<cmd> = self.substitute-vars($action<c>);
    note "Set command to\n  ", $action-data<cmd>.split("\n").join("\n  ")
      if $*verbose;
  }

  # Set icon on the button. If not specified, try a different path
  my Str $picture-file;
  if ? $action<i> {
    $picture-file = self.substitute-vars($action<i>);
  }

  else {
    $picture-file = "$*images/$session-name/$level$count.png";
  }

  if ? $picture-file {
    $action-data<picture-file> = $!config.set-path($picture-file);
  }

  # Set overlay icon over the button
  if ? $action<o> {
    $picture-file = self.substitute-vars($action<o>);
  }

  else {
    $picture-file = "$*images/$session-name/o$level$count.png";
  }

  if ? $picture-file {
    $action-data<overlay-picture-file> = $!config.set-path($picture-file);
  }

  if ? $action<v> {
    $action-data<temp-variables> = $action<v>;
  }

  if ! $action-data<tooltip> and ? $action-data<cmd> {
    my Str $tooltip = $action-data<cmd>;
    $tooltip ~~ s/ \s .* $//;
    note "Set tooltip to\n  ", $tooltip.split("\n").join("\n  ")
      if $*verbose;
    $action-data<tooltip> = $tooltip;
  }

  $action-data
}

#-------------------------------------------------------------------------------
method action-button ( Hash $action-data --> Gnome::Gtk4::Overlay ) {
  my Gnome::Gtk4::Overlay $overlay .= new-overlay;
  my Gnome::Gtk4::Picture $overlay-pic;
  my Gnome::Gtk4::Picture $picture;

  with $picture .= new-picture {
    .set-filename($action-data<picture-file>);
    .set-size-request($!config.get-icon-size);
  }

  with my Gnome::Gtk4::Button $button .= new-button {
    .set-child($picture);
    .set-tooltip-text($action-data<tooltip>);
    $!config.set-css( .get-style-context, 'session-button');
    .register-signal( self, 'run-action', 'clicked', :$action-data);
  }

  $overlay.set-child($button);

  if $action-data<overlay-picture-file>:exists and
    $action-data<overlay-picture-file>.IO.r
  {
    # Need to use a box or resize the picture, otherwise it will
    # use up all of the overlay area if the picture is large.
    my $err = CArray[N-Error].new(N-Error);
    my Int ( $w, $h) = ($!config.get-icon-size.List X/ 3)>>.Int;

    my Gnome::GdkPixbuf::Pixbuf $gdkpixbuf .= new-from-file-at-size(
      $action-data<overlay-picture-file>, $w, $h, $err
    );

    with $overlay-pic .= new-for-pixbuf($gdkpixbuf) {
      $overlay.add-overlay($overlay-pic);
      .set-halign(GTK_ALIGN_END);
      .set-valign(GTK_ALIGN_END);

      $!config.set-css( .get-style-context, 'overlay-pic');
    }
  }

  $overlay
}

#-------------------------------------------------------------------------------
method run-action ( Hash :$action-data ) {

  $!config.set-temp-variables($action-data<temp-variables>)
    if $action-data<temp-variables>:exists;

  my Str ( $k, $v, $cmd);
  if ? $action-data<env> {
    for $action-data<env>.split(';') -> $es {
      ( $k, $v ) = $es.split('=');
      %*ENV{$k} = $v;
    }
  }

  $cmd = '';
  $cmd ~= "cd '$action-data<work-dir>'\n" if ? $action-data<work-dir>;
  $cmd ~= $action-data<cmd> if ? $action-data<cmd>;
  $cmd = self.substitute-vars( $cmd, :v($!config.get-temp-variables));

  my Str $script-name;
  $script-name = '/tmp/' ~ sha256-hex($cmd) ~ ".shell-script";
  $script-name.IO.spurt($cmd);
  note "\nRun script $!shell, $script-name" if $*verbose;

  my Proc $p = shell(
    "$!shell {$*verbose ?? '-xv ' !! ''}$script-name > /tmp/script.log &"
  );

  %*ENV{$k}:delete if ?$k and ?$v;
}

#-------------------------------------------------------------------------------
method substitute-vars ( Str $t, Hash :$v --> Str ) {

  my Hash $variables = $v // $!config.get-variables;
  my Str $text = $t;

  while $text ~~ m/ '$' $<variable-name> = [<alpha> | <[0..9]> | '-']+ / {
    my Str $name = $/<variable-name>.Str;
    if $variables{$name}:exists {
      $text ~~ s:g/ '$' $name /$variables{$name}/;
    }

    else {
      note "No substitution yet or variable \$$name" if $*verbose;
      $text ~~ s:g/ '$' $name /___$name/;
    }
  }

  $text ~~ s:g/ '___' ([<alpha> | <[0..9]> | '-']+) /\$$0/;

  $text
}
