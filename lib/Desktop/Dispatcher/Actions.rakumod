
use v6.d;

use NativeCall;

use Desktop::Dispatcher::Config;

use Gnome::Gtk4::Box:api<2>;
use Gnome::Gtk4::Button:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Picture:api<2>;
use Gnome::Gtk4::Frame:api<2>;
use Gnome::Gtk4::T-enums:api<2>;

use Gnome::N::N-Object:api<2>;

#-------------------------------------------------------------------------------
unit class Desktop::Dispatcher::Actions:auth<github:MARTIMM>;

has Desktop::Dispatcher::Config $!config;
has Bool $!init-config;

#-------------------------------------------------------------------------------
submethod BUILD ( Desktop::Dispatcher::Config:D :$!config ) {
  $!init-config = True;
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

  for $!config.get-sessions -> $session-name {
    my Str $session-title = $!config.get-session-title($session-name);
    my Str $picture-file =
      self.substitute-vars($!config.get-session-icon($session-name));

    with my Gnome::Gtk4::Picture $picture .= new-picture {
      .set-filename($picture-file);
      .set-size-request( 100, 100);

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

    $toolbar.append($button);
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

  my Gnome::Gtk4::Box $session-buttons .= new-box(GTK_ORIENTATION_HORIZONTAL);
  $session-frame.set-child($session-buttons);

  with $session-buttons {
    .set-spacing(20);
    .set-margin-top(0);
    .set-margin-bottom(30);
    .set-margin-start(30);
    .set-margin-end(30);

    for $!config.get-session-action($session-name) -> $action {
      my Str $picture-file = DATA_DIR ~ '/Images/config-icon.jpg';
      my Hash $action-data = %(:$session-name);

      # Get tooltip text
      if ? $action<t> {
        $action-data<tooltip> = self.substitute-vars($action<t>);
      }

      # Set path to work directory
      if ? $action<p> {
        $action-data<work-dir> = self.substitute-vars($action<p>);
      }

      # Set environment
      if ? $action<e> {
        $action-data<env> = self.substitute-vars($action<e>);
      }

      # Script to run before command can run
      if ? $action<s> {
        $action-data<script> = self.substitute-vars($action<s>);
      }

      # Set command to run
      if ? $action<c> {
        $action-data<cmd> = self.substitute-vars($action<c>);
      }

      # Set icon on the button
      if ? $action<i> {
        $picture-file = self.substitute-vars($action<i>);
        $picture-file = [~] $!config.config-directory, '/', $picture-file
          unless $picture-file.index('/') == 0;
      }

      if ! $action-data<tooltip> and ? $action-data<cmd> {
        my Str $tooltip = $action-data<cmd>;
        $tooltip ~~ s/ \s .* $//;
        $action-data<tooltip> = $tooltip;
      }

      my Gnome::Gtk4::Button $button =
        self.action-button( $picture-file, $action-data, $session-buttons);
      .append($button);
    }
  }
}

#-------------------------------------------------------------------------------
method action-button (
  Str $picture-file, Hash $action-data, Gnome::Gtk4::Box $session-buttons
  --> Gnome::Gtk4::Button
) {
  with my Gnome::Gtk4::Picture $picture .= new-picture {
    .set-filename($picture-file);
    .set-size-request($!config.get-icon-size);
  }

  with my Gnome::Gtk4::Button $button .= new-button {
    .set-child($picture);
    .set-tooltip-text($action-data<tooltip>);
    $!config.set-css( .get-style-context, 'session-button');
    .register-signal( self, 'run-action', 'clicked', :$action-data);
  }

  $button
}

#-------------------------------------------------------------------------------
method run-action ( Hash :$action-data ) {

  my Str ( $k, $v, $cmd);
  if ? $action-data<env> {
    for $action-data<env>.split(';') -> $es {
      ( $k, $v ) = $es.split('=');
      %*ENV{$k} = $v;
    }
  }

  $cmd = '';
  $cmd ~= [~] 'cd ', $action-data<work-dir>, ';' if ? $action-data<work-dir>;
  $cmd ~= $action-data<cmd> if ? $action-data<cmd>;

  $cmd ~~ s:g/ \s ** 2..* / /;

  shell $cmd ~ ' &';

  if ?$k and ?$v {
    %*ENV{$k}:delete;
  }
}

#-------------------------------------------------------------------------------
method substitute-vars ( Str $text is copy --> Str ) {
  my Hash $variables = $!config.get-variables;
  while $text ~~ m/ '$' $<variable-name> = [<alpha> | <[0..9]> | '-']+ / {
    my Str $name = $/<variable-name>.Str;
    if $variables{$name}:exists {
      $text ~~ s:g/ '$' $name /$variables{$name}/;
    }

    else {
      die "No substitution for variable \$$name";
    }
  }

  $text
}

