
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
method setup-sessions ( --> Box ) {

  with my Box $sessions .= new-box( GTK_ORIENTATION_VERTICAL, 1) {
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
#method make-toolbar ( Box $sessions --> ScrolledWindow ) {
method make-toolbar ( Box $sessions --> Box ) {
  with my Box $toolbar .= new-box( GTK_ORIENTATION_HORIZONTAL, 1) {
    $!config.set-css( .get-style-context, 'session-toolbar');
    .set-spacing(10);
  }

  # First a series of direct action buttons
  my $count = 0;
#note "$?LINE ", $!config.get-toolbar-actions.gist;
  for $!config.get-toolbar-actions -> Hash $action {
    CONTROL { when CX::Warn {  note .gist; .resume; } }
    CATCH { default { .message.note; .backtrace.concise.note } }

#note "$?LINE ", $action.gist;
    #my Hash $action-data = 
    self.process-action( :$action, :level(0), :$count);

    $!action-data<toolbar><tooltip> =
      "Run\n$!action-data<toolbar><tooltip>";

    with my Picture $picture .= new-picture {
      .set-filename($!action-data<toolbar><picture-file>);
      .set-size-request($!config.get-icon-size);

      .set-margin-top(0);
      .set-margin-bottom(0);
      .set-margin-start(0);
      .set-margin-end(0);
    }

    my Overlay $overlay = self.action-button( $!action-data, 'toolbar');
    if $!action-data<toolbar><overlay-picture-file>:exists and
      $!action-data<toolbar><overlay-picture-file>.IO.r
    {
      with my Picture $overlay-pic .= new-for-paintable(
        self.set-texture($!action-data<toolbar><overlay-picture-file>)
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
method session-actions ( Str :$session-name, Box :$sessions ) {
  state Frame $session-frame;

  if !$session-frame {
    $session-frame.clear-object if ?$session-frame;
    with $session-frame .= new-frame('') {
      $!config.set-css( .get-style-context, 'session-frame');
      .set-margin-top(0);
      .set-margin-bottom(0);
      .set-margin-start(0);
      .set-margin-end(0);
      my Label() $label = .get-label-widget;
      $!config.set-css( $label.get-style-context, 'session-frame-label');
    }

    $sessions.append($session-frame);
  }

  $session-frame.set-label-widget(self.frame-label-widget($session-name));

  my Box $session-levels .= new-box( GTK_ORIENTATION_VERTICAL, 1);
  $session-frame.set-child($session-levels);

  $!app-window.set-default-size($!config.get-window-size);
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

      my UInt $count = 0;
      for $!config.get-session-actions( $session-name, :$level) -> $action {
        my Hash $button-action =
          self.process-action( :$session-name, :$action, :$level, :$count);
        my Overlay $overlay =
          self.action-button( $button-action, $session-name);
        .append($overlay);

        $count++;
      }
    }
  }
}

#-------------------------------------------------------------------------------
method frame-label-widget ( Str $session-name --> Mu ) {
#note "$?LINE run-all-actions: $session-name, ", $!config.run-all-actions($session-name);

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
method run-all-actions ( Str :$session-name --> Mu ) {
note "run all entries of $session-name, ", $!action-data{$session-name}.gist;
#  self.run-action(:$session-name);
}

#-------------------------------------------------------------------------------
method process-action (
   Str :$session-name = 'toolbar', Hash :$action, UInt :$level, UInt :$count
   --> Hash
) {
  #$!action-data{$session-name} = %() unless ? $!action-data{$session-name};
  $!action-data{$session-name} = %(
    :$session-name, :$level, :picture-file(DATA_DIR ~ '/Images/config-icon.jpg')
  );

  note "\nSession data for $session-name";# if $*verbose;

  # Get tooltip text
  if ? $action<t> {
    $!action-data{$session-name}<tooltip> = self.substitute-vars($action<t>);
    note "Set tooltip to\n  ", $!action-data{$session-name}<tooltip>.split("\n").join("\n  ")
      if $*verbose;
  }

  # Set path to work directory
  if ? $action<p> {
    $!action-data{$session-name}<work-dir> = self.substitute-vars($action<p>);
#    note "Set workdir to $!action-data<work-dir>" if $*verbose;
  }

  # Set environment
  if ? $action<e> {
    $!action-data{$session-name}<env> = [];
    for @($action<e>) -> $a {
      $!action-data{$session-name}<env>.push: self.substitute-vars($a);
    }
#    note "Set environment to $!action-data<env>" if $*verbose;
  }

  # Script to run before command can run
  if ? $action<s> {
    $!action-data{$session-name}<script> = self.substitute-vars($action<s>);
    note "Set script to\n  ", $!action-data{$session-name}<script>.split("\n").join("\n  ")
      if $*verbose;
  }

  # Set command to run
  if ? $action<c> {
    $!action-data{$session-name}<cmd> = self.substitute-vars($action<c>);
    note "Set command to\n  ", $!action-data{$session-name}<cmd>.split("\n").join("\n  ")
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
    $!action-data{$session-name}<picture-file> = $!config.set-path($picture-file);
  }

  # Set overlay icon over the button
  if ? $action<o> {
    $picture-file = self.substitute-vars($action<o>);
  }

  else {
    $picture-file = "$*images/$session-name/o$level$count.png";
  }

  if ? $picture-file {
    $!action-data{$session-name}<overlay-picture-file> = $!config.set-path($picture-file);
  }

  if ? $!action-data<v> {
    $!action-data{$session-name}<temp-variables> = $action<v>;
  }

  if ! $!action-data{$session-name}<tooltip> and ? $!action-data{$session-name}<cmd> {
    my Str $tooltip = $!action-data{$session-name}<cmd>;
    $tooltip ~~ s/ \s .* $//;
    note "Set tooltip to\n  ", $tooltip.split("\n").join("\n  ")
      if $*verbose;
    $!action-data{$session-name}<tooltip> = $tooltip;
  }

#  $session-name
  $!action-data
}

#-------------------------------------------------------------------------------
method action-button ( Hash $action-data, Str $session-name --> Overlay ) {
  my Overlay $overlay .= new-overlay;
  my Picture $overlay-pic;
  my Picture $picture;

my Hash $action := $action-data{$session-name};
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
method substitute-vars ( Str $t, Hash :$v --> Str ) {

  my Hash $variables = $v // $!config.get-variables;
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
