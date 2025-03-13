
use v6.d;

use NativeCall;

use Desktop::Dispatcher::Config;

use Gnome::Gtk4::ApplicationWindow:api<2>;
use Gnome::Gtk4::Box:api<2>;
use Gnome::Gtk4::Button:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Picture:api<2>;
use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::Frame:api<2>;
use Gnome::Gtk4::T-enums:api<2>;
use Gnome::Gtk4::Overlay:api<2>;
use Gnome::Gtk4::PopoverMenu:api<2>;
use Gnome::Gtk4::ScrolledWindow:api<2>;

use Gnome::GdkPixbuf::Pixbuf:api<2>;
use Gnome::Gdk4::Texture:api<2>;

use Gnome::Glib::N-Error:api<2>;
use Gnome::Glib::T-error:api<2>;

use Gnome::N::N-Object:api<2>;

use Digest::SHA256::Native;

#-------------------------------------------------------------------------------
unit class Desktop::Dispatcher::Actions:auth<github:MARTIMM>;

constant Box = Gnome::Gtk4::Box;
constant Grid = Gnome::Gtk4::Grid;
constant ApplicationWindow = Gnome::Gtk4::ApplicationWindow;
constant ScrolledWindow = Gnome::Gtk4::ScrolledWindow;
constant Button = Gnome::Gtk4::Button;
constant Label = Gnome::Gtk4::Label;
constant Picture = Gnome::Gtk4::Picture;
constant Frame = Gnome::Gtk4::Frame;
constant Overlay = Gnome::Gtk4::Overlay;

constant Pixbuf = Gnome::GdkPixbuf::Pixbuf;
constant Texture = Gnome::Gdk4::Texture;

has Desktop::Dispatcher::Config $!config;
#has Bool $!init-config;
has Str $!shell; 
has ApplicationWindow $!app-window;
has Hash $!action-data;

#-------------------------------------------------------------------------------
submethod BUILD (
  Desktop::Dispatcher::Config:D :$!config, ApplicationWindow :$!app-window
) {
#  $!init-config = True;
  $!shell = $!config.get-shell;
  $!action-data = %();
}

#-------------------------------------------------------------------------------
method setup-sessions ( --> Grid ) {

  with my Grid $sessions .= new-grid {
    .set-margin-top(0);
    .set-margin-bottom(0);
    .set-margin-start(0);
    .set-margin-end(0);

    .attach( self.make-toolbar($sessions), 0, 0, 1, 1);
    $!config.set-css( .get-style-context, 'sessions');
  }

  $sessions
}

#-------------------------------------------------------------------------------
# The top row of icons is the toolbar. 
#method make-toolbar ( Box $sessions --> ScrolledWindow ) {
method make-toolbar ( Grid $sessions --> Box ) {
  with my Box $toolbar .= new-box( GTK_ORIENTATION_HORIZONTAL, 1) {
    $!config.set-css( .get-style-context, 'session-toolbar');
    .set-spacing(10);
  }

  # Prepare. First a series of direct action buttons - shortcuts
  $!action-data<toolbar> = [];
  my $count = 0;

  for $!config.get-toolbar-actions -> Hash $action {
    my Hash $action-data = self.process-action(
      :session-name<toolbar>, :$action, :level(0), :$count
    );
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

#-------------------------------------------------------------------------------
# Session button pressed to show the action buttons in groups
method session-actions ( Str :$session-name, Grid :$sessions ) {

  with my Frame $session-frame .= new-frame('') {
    $!config.set-css( .get-style-context, 'session-frame');
    .set-margin-top(0);
    .set-margin-bottom(0);
    .set-margin-start(0);
    .set-margin-end(0);
    my Label() $label = .get-label-widget;
    $!config.set-css( $label.get-style-context, 'session-frame-label');
    .set-label-widget(self.frame-label-widget($session-name));
  }

  # The first row is for shortcuts and sessions. The second for
  # actions of a session
  $sessions.remove-row(1) if $sessions.get-child-at( 0, 1);
  $sessions.attach( $session-frame, 0, 1, 1, 1);

  my Box $session-levels .= new-box( GTK_ORIENTATION_VERTICAL, 1);
  $session-frame.set-child($session-levels);

  $!app-window.set-default-size($!config.get-window-size);

  # 
  loop ( my UInt $level = 0; $level < 7; $level++ ) {
    last unless $!config.has-actions-level( $session-name, :$level);

    my Box $session-buttons .= new-box( GTK_ORIENTATION_HORIZONTAL, 1);
    $session-levels.append($session-buttons);

    with $session-buttons {
      .set-spacing(20);
      .set-margin-top(0);
      .set-margin-bottom(30);
      .set-margin-start(30);
      .set-margin-end(30);

      # Clear first
      $!action-data{$session-name} = [];
      my UInt $count = 0;
      for $!config.get-session-actions( $session-name, $level) -> $action {
        my Overlay $overlay = self.action-button(
          self.process-action( :$session-name, :$action, :$level, :$count)
        );

        .append($overlay);

        $count++;
      }
    }
  }
}

#-------------------------------------------------------------------------------
method frame-label-widget ( Str $session-name --> Mu ) {

  my Str $session-title = $!config.get-session-title($session-name);
  my Label $label .= new-label($session-title);
  $!config.set-css( $label.get-style-context, 'session-frame-label');

  if $!config.run-all-actions($session-name) {
    my Str $png-file = [~] DATA_DIR, '/Images/fastforward.png>';
    my Box $frame-label-widget .= new-box( GTK_ORIENTATION_HORIZONTAL, 5);

    my Picture $picture .= new-picture;
    $picture.set-filename(%?RESOURCES<fastforward.png>.IO.Str);
    $picture.set-size-request( 32, 32);

    my Button $run-all-actions .= new-button;
    $run-all-actions.set-child($picture);
    $run-all-actions.register-signal(
      self, 'run-all-actions', 'clicked', :$session-name
    );

    $frame-label-widget.append($run-all-actions);
    $frame-label-widget.append($label);

    $frame-label-widget
  }

  else {
    $label
  }
}

#-------------------------------------------------------------------------------
method process-action (
   Str :$session-name, Hash :$action, UInt :$level, UInt :$count
   --> Hash
) {
  my Hash $ad = %(
    :$session-name, :$level, :picture-file(DATA_DIR ~ '/Images/config-icon.jpg')
  );

#note "$?LINE $action.gist()";
#  note "\nSession data for $session-name" if $*verbose;

  # Get tooltip text
  if ? $action<t> {
    $ad<tooltip> = self.substitute-vars($action<t>);
    note "Set tooltip to\n  ", $ad<tooltip>.split("\n").join("\n  ")
      if $*verbose;
  }

  # Set path to work directory
  if ? $action<p> {
    $ad<work-dir> = self.substitute-vars($action<p>);
#    note "Set workdir to $ad<work-dir>" if $*verbose;
  }

  # Set environment
  if ? $action<e> {
    $ad<env> = [];
    for @($action<e>) -> $a {
      $ad<env>.push: self.substitute-vars($a);
    }
#    note "Set environment to $ad<env>" if $*verbose;
  }

  # Script to run before command can run
  if ? $action<s> {
    $ad<script> = self.substitute-vars($action<s>);
    note "Set script to\n  ", $ad<script>.split("\n").join("\n  ")
      if $*verbose;
  }

  # Set command to run
  if ? $action<c> {
    $ad<cmd> = self.substitute-vars($action<c>);
    note "Set command to\n  ", $ad<cmd>.split("\n").join("\n  ")
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
    $ad<picture-file> = $!config.set-path($picture-file);
  }

  # Set overlay icon over the button
  if ? $action<o> {
    $picture-file = self.substitute-vars($action<o>);
  }

  else {
    $picture-file = "$*images/$session-name/o$level$count.png";
  }

  if ? $picture-file {
    $ad<overlay-picture-file> = $!config.set-path($picture-file);
  }

  if ? $action<v> {
    $ad<temp-variables> = $action<v>;
  }

  if ! $ad<tooltip> and ? $ad<cmd> {
    my Str $tooltip = $ad<cmd>;
    $tooltip ~~ s/ \s .* $//;
    note "Set tooltip to\n  ", $tooltip.split("\n").join("\n  ")
      if $*verbose;
    $ad<tooltip> = $tooltip;
  }

  $!action-data{$session-name}.push: %(|$ad);

  $ad
}

#-------------------------------------------------------------------------------
method action-button ( Hash $action --> Overlay ) {
  my Overlay $overlay .= new-overlay;
  my Picture $overlay-pic;
  my Picture $picture;

#my Hash $action := $action-data{$session-name};
#note "\n$?LINE action-button $session-name, {$action.gist}, $action<picture-file>, $action<tooltip>";

  with $picture .= new-picture {
    .set-filename($action<picture-file>);
    .set-size-request($!config.get-icon-size);
  }

  with my Button $button .= new-button {
    .set-child($picture);
    .set-tooltip-text($action<tooltip>);
    $!config.set-css( .get-style-context, 'session-button');
    .register-signal( self, 'run-action', 'clicked', :$action);
  }

  $overlay.set-child($button);

  if $action<overlay-picture-file>:exists and
    $action<overlay-picture-file>.IO.r
  {
    with my Picture $overlay-pic .= new-for-paintable(
      self.set-texture($action<overlay-picture-file>)
    ) {
      $overlay.add-overlay($overlay-pic);
      .set-halign(GTK_ALIGN_END);
      .set-valign(GTK_ALIGN_END);

      $!config.set-css( .get-style-context, 'overlay-pic');
    }
  }

  $overlay
}

#-------------------------------------------------------------------------------
#method run-action ( Hash :$action-data ) {
method run-action ( Hash :$action ) {

#  my Hash $action-data := $!action-data{$session-name};
  $!config.set-temp-variables($action<temp-variables>)
    if $action<temp-variables>:exists;

  my Str ( $k, $v, $cmd);
  if ? $action<env> {
    note "Set environment to; " if $*verbose;
    for @($action<env>) -> $es {
      ( $k, $v ) = $es.split('=');
      note "   $k = $v" if $*verbose;
      %*ENV{$k} = $v;
    }
  }

  $cmd = '';
  if ? $action<work-dir> {
    $cmd ~= "cd '$action<work-dir>'\n";
    note "Set workdir to $action<work-dir>" if $*verbose;
  }
  $cmd ~= $action<cmd> if ? $action<cmd>;
  $cmd = self.substitute-vars( $cmd, :v($!config.get-temp-variables));

  my Str $script-name;
  $script-name = '/tmp/' ~ sha256-hex($cmd) ~ '.shell-script';
  $script-name.IO.spurt($cmd);
  note "\nRun script $!shell, $script-name" if $*verbose;

  my Proc $p = shell(
    "$!shell {$*verbose ?? '-xv ' !! ''}$script-name > /tmp/script.log &"
  );

  %*ENV{$k}:delete if ?$k and ?$v;
}

#-------------------------------------------------------------------------------
method run-all-actions ( Str :$session-name --> Mu ) {
  for @($!action-data{$session-name}) -> $action {
    note "Start $action<cmd>";
    self.run-action(:$action);
  }
}

#-------------------------------------------------------------------------------
method substitute-vars ( Str $t, Hash :$v --> Str ) {

  my Hash $variables = $!config.get-variables;
  $variables.append: $v if ?$v;
#note "\n$?LINE $variables.gist()";
#note "\n$?LINE $variables<thunderbird-o>";
#exit;
  my Str $text = $t;

  while $text ~~ m/ '$' $<variable-name> = [<alpha> | \d | '-']+ / {
    my Str $name = $/<variable-name>.Str;
#note "$?LINE $text --- $name";
    # Look in the variables Hash
    if $variables{$name}:exists {
      $text ~~ s:g/ '$' $name /$variables{$name}/;
    }

    # Look in the environment
    elsif %*ENV{$name}:exists {
      $text ~~ s:g/ '$' $name /%*ENV{$name}/;
    }

    # Fail and block variable by substituting $ for __
    else {
      note "No substitution yet or variable \$$name" if $*verbose;
      $text ~~ s:g/ '$' $name /___$name/;
    }
  }

  $text ~~ s:g/ '___' ([<alpha> | <[0..9]> | '-']+) /\$$0/;

#note "$?LINE $text";
#printf "\n";

  $text
}

#-------------------------------------------------------------------------------
method set-texture ( Str $file --> Texture ) {

  # Need to use a box or resize the picture, otherwise it will
  # use up all of the overlay area if the picture is large.
  my $err = CArray[N-Error].new(N-Error);
  my Int ( $w, $h) = ($!config.get-icon-size.List X/ 3)>>.Int;
  my Gnome::GdkPixbuf::Pixbuf $gdkpixbuf .= new-from-file-at-size(
    $file, $w, $h, $err
  );

  Texture.new-for-pixbuf($gdkpixbuf)
}
