
use v6.d;

use NativeCall;

use Desktop::Dispatcher::Config;

use Gnome::Gtk4::Box:api<2>;
use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::Button:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Picture:api<2>;
use Gnome::Gtk4::Frame:api<2>;
use Gnome::Gtk4::ScrolledWindow:api<2>;
use Gnome::Gtk4::T-enums:api<2>;

use Gnome::N::N-Object:api<2>;

#-------------------------------------------------------------------------------
unit class Desktop::Dispatcher::Actions:auth<github:MARTIMM>;

has Desktop::Dispatcher::Config $!config;

#-------------------------------------------------------------------------------
submethod BUILD (
  Desktop::Dispatcher::Config:D :$!config,
) {
}

#-------------------------------------------------------------------------------
method setup-sessions ( --> Gnome::Gtk4::ScrolledWindow ) {
  my Gnome::Gtk4::Box $sessions .= new-box(GTK_ORIENTATION_VERTICAL);
  with $sessions {
    .set-margin-top(0);
    .set-margin-bottom(0);
    .set-margin-start(0);
    .set-margin-end(0);
  }

  my Gnome::Gtk4::ScrolledWindow $container .= new-scrolledwindow;
  $container.set-child($sessions);
  $!config.set-css( $sessions.get-style-context, 'sessions');

  my Int $row = 0;
  my Int $max-cols = 0;

  for $!config.get-sessions -> $session-name {

    my Str $session-title = $!config.get-session-title($session-name);
    with my Gnome::Gtk4::Frame $session-frame .= new-frame($session-title) {
      $!config.set-css( $session-frame.get-style-context, 'session-frame');
      .set-margin-top(0);
      .set-margin-bottom(0);
      .set-margin-start(0);
      .set-margin-end(0);
    }

    my Gnome::Gtk4::Box $session-buttons .= new-box(GTK_ORIENTATION_HORIZONTAL);
    $session-frame.set-child($session-buttons);

    with $session-buttons {
      .set-spacing(20);
      .set-margin-top(0);
      .set-margin-bottom(30);
      .set-margin-start(30);
      .set-margin-end(30);

      my Int $cols = 0;
      for $!config.get-session-action($session-name) -> $action {
        my Str $picture-file = DATA_DIR ~ '/Images/config-icon.jpg';
        my Hash $action-data = %(:$session-name);

        # Get tooltip text
        if ? $action<t> {
          $action-data<tooltip> = $action<t>;
        }

        # Set path to work directory
        if ? $action<p> {
          $action-data<work-dir> = self.substitute-vars($action<p>);
        }

        # Set environment
        if ? $action<e> {
          $action-data<env> = $action<e>;
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
        $cols++;
      }

      $max-cols = max( $max-cols, $cols);
    }

    $sessions.append($session-frame);
    $row++;
  }

  my Int ( $iw, $ih) = $!config.get-icon-size;
  
  # Button padding, borders, picture width: $max-cols * (10 + 10 + $iw)
  # Space between columns: 20 * ($max-cols - 1)
  # Left and right of a row: 2 * 30
  # Unknown (yet) extra to get in all view: 10
  my Int $width = $max-cols * (10 + 10 + $iw)
                  + 20 * ($max-cols - 1) + 2 * 30 + 10;

  # Height of the picture: $ih
  # Borders around picture and button padding: 10 + 10
  # Top space guess (30) and bottom space (30): 60
  # Unknown (yet) extra to get in all view: 20 
  my Int $height = $row * ($ih + 60 + 10 + 10) + 20;

note "$?LINE new size: $width, $height";
  $container.set-size-request( $width, $height);

  $container
}

#-------------------------------------------------------------------------------
method action-button (
  Str $picture-file, Hash $action-data,
  Gnome::Gtk4::Box $session-buttons
  --> Gnome::Gtk4::Button
) {
  with my Gnome::Gtk4::Picture $picture .= new-picture {
    .set-filename($picture-file);
    .set-size-request($!config.get-icon-size);
  }

  with my Gnome::Gtk4::Button $button .= new-button {
    .set-child($picture);
    .set-tooltip-text($action-data<tooltip>);
    $!config.set-css( $button.get-style-context, 'session-button');
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

