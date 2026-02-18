
use v6.d;

use SessionManager::Variables;
use Digest::SHA256::Native;

#-------------------------------------------------------------------------------
unit class SessionManager::ActionData;

# ID is readable for easy access
has Str $.id;
has Bool $.run-in-group;

#has Proc::Async $!process;
has Str $.run-error;
has Str $.run-log;
has Bool $.running;
has Str $!shell;
has Supplier $!supplier;
has Supply $!supply handles <tap>;

has Str $.tooltip;
has Str $!workdir;
has Hash $!env;
has Str $!script;
has Str $!cmd;
has Bool $.cmd-logging;
has UInt $.cmd-finish-wait;
has Bool $!cmd-background;

# Picture paths are readable to be able to set on a button or elsewhere
has Str $.picture;
has Str $.overlay-picture;

has Hash $!temp-variables;
has SessionManager::Variables $!variables;

# For save keeping
has Hash $.raw-action;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  $!supplier .= new;
  $!supply = $!supplier.Supply;
}

#-------------------------------------------------------------------------------
method init-action ( Str :$!id = '', Hash:D :$!raw-action ) {
  $!run-in-group = False;
  $!running = False;

  $!variables .= new;

  # Get tooltip text
  $!tooltip = $!variables.substitute-vars($!raw-action<t>) if ? $!raw-action<t>;

  # Set path to work directory
  $!workdir = $!variables.substitute-vars($!raw-action<p>) if ? $!raw-action<p>;

  # Set environment as a Hash
  $!env = $!raw-action<e> if ? $!raw-action<e>;

  # Script to run before command can run
  $!script = $!variables.substitute-vars($!raw-action<s>) if ? $!raw-action<s>;

  # Set command to run
  if ? $!raw-action<c> {
    $!cmd = $!variables.substitute-vars($!raw-action<c>);
    $!cmd-logging = False;    # $!raw-action<l>
    $!cmd-finish-wait = 10;   # $!raw-action<w>
    $!cmd-background = True;  # $!raw-action<b>
    if $!raw-action<l>.defined {
      $!cmd-logging = ? $!raw-action<l>;
      $!cmd-background = False;
    }

    $!cmd-finish-wait = $!raw-action<w> if $!raw-action<w>.defined;
    $!shell = $!raw-action<sh> if $!raw-action<sh>.defined;
  }

  # Set icon on the button.
  $!picture = $!variables.substitute-vars($!raw-action<i>)
    if ? $!raw-action<i>;

  # Set overlay icon over the button
  $!overlay-picture = $!variables.substitute-vars($!raw-action<o>)
    if ? $!raw-action<o>;

  # If there is no ID, generate an MD5 from the tooltip or a random number
  $!id = sha256-hex($!tooltip // rand.Str) unless ? $!id;
}

#-------------------------------------------------------------------------------
method modify-id ( Str $!id ) { }

#`{{
#-------------------------------------------------------------------------------
method set-image-to-session-path (
  Str $session-name, Str $image-name, Bool :$overlay = False
) {
  if $overlay {
    $!overlay-picture = "$*images/$session-name/$image-name";
  }

  else {
    $!picture = "$*images/$session-name/$image-name";
  }
}
}}

#-------------------------------------------------------------------------------
method set-run-in-group ( Bool $!run-in-group ) { }

#-------------------------------------------------------------------------------
method run-action ( ) {     #( Bool $!run-in-group ) {
#note "$?LINE run action '$!tooltip'";

  # Set temporary variables if any
  $!variables.set-temporary($!temp-variables) if ?$!temp-variables;

  # Set environment variables
  if ? $!env {
    for $!env.keys -> $name {
      %*ENV{$name} = $!env{$name};
    }
  }

  my Str $command = '';
  $command ~= "cd '$!workdir'\n" if ? $!workdir;
  $command ~= $!cmd if ? $!cmd;
  $command = $!variables.substitute-vars($command);

  my Str $script-name;
  $script-name = '/tmp/' ~ sha256-hex($command) ~ '.shell-script';
  $script-name.IO.spurt($command);

  my $shell = ?$!shell ?? $!shell !! '/usr/bin/bash';

  if $!cmd-background {
    shell "$shell $script-name &> /dev/null \&";
#`{{
    $script-name.IO.unlink;

    # Remove environment variables
    if ? $!env {
      for $!env.keys -> $name {
        %*ENV{$name}:delete;
      }
    }
}}
  }

  else {
    my Proc::Async $process;
    $process .= new( $shell, $script-name);
    $!run-log = '';
    $!run-error = '';
    $!running = True;

    my Promise $promise = start {
      react {
        whenever $process.stdout.lines {
          $!run-log ~= "$_\n";
          $!supplier.emit("N> $_\n") if $!cmd-logging;
        }

        whenever $process.stderr.lines {
          $!run-error ~= "$_\n";
          $!supplier.emit("E> $_\n") if $!cmd-logging;
        }

        whenever $process.ready {
          if $_ ~~ Broken {
            $!run-error ~= "Script failed to start or has errors\n";
            $!supplier.emit("E> Script failed to start or has errors\n")
              if $!cmd-logging;
          }

          else {
            my Str $l = "\n$command\n\nN> Program started ok, Pid: $_\n";
            $!run-log ~= $l;
            $!supplier.emit("N> $l") if $!cmd-logging;
          }
        }

        whenever $process.start {
          my Str $l =
            "Program finished: exitcode={.exitcode}, signal={.signal}\n";
          $!run-log ~= $l;
          $!supplier.emit("N> $l") if $!cmd-logging;
          $!supplier.done;
          $!running = False;

          await $promise;
          done;
        }
      }

#note "$?LINE $!run-log";
      $script-name.IO.unlink;

      # Remove environment variables
      if ? $!env {
        for $!env.keys -> $name {
          %*ENV{$name}:delete;
        }
      }
    }
  }
}

#-------------------------------------------------------------------------------
# Substitute changed variable in the raw actions Hash.
method subst-vars ( Str:D $original-var, Str:D $new-var ) {
  my Hash $raw-action = $!raw-action;
  my Str $id = $!id;

  for $raw-action.keys -> $type {
    next unless $raw-action{$type} ~~ Str;
    my Str $v = $raw-action{$type};
    $v ~~ s:g/ '$' $original-var (<-[\w-]>?) /\$$new-var$0/;
    $raw-action{$type} = $v;
  }

  self.init-action( :$id, :$raw-action);
}

#-------------------------------------------------------------------------------
method is-var-in-use ( Str:D $v --> Bool ) {
  my Bool $in-use = False;

  for $!raw-action.kv -> $type, $value {
    next unless $value ~~ Str;
    if $value ~~ m/ '$' $v (<-[\w-]>?) / {
      $in-use = True;
      last;
    }
  }

  $in-use
}
