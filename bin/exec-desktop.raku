#!/bin/env -S rakudo -Ilib
use YAMLish;

sub MAIN ( Str $desktop-file ) {
  die 'Desktop file not found or executable' unless $desktop-file.IO.x;

  my Hash $config = load-yaml(slurp($desktop-file));
  my Str ( $exec, $work-dir, $env );

  $exec = $config<exec> // '';
  $work-dir = $config<path> // '';
  $env = $config<env> // '';

#  note "$env, $work-dir, $exec";

  my Str ( $k, $v, $cmd);
  if ? $env {
    for $env.split(';') -> $es {
      ( $k, $v ) = $es.split('=');
      %*ENV{$k} = $v;
    }
  }

  $cmd = '';
  $cmd ~= [~] 'cd ', $work-dir, ';' if ? $work-dir;
  $cmd ~= $exec if ? $exec;

  $cmd ~~ s:g/ \s ** 2..* / /;

  shell $cmd ~ ' &';

  if ?$k and ?$v {
    %*ENV{$k}:delete;
  }
}

