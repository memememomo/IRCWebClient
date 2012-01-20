use strict;
use warnings;
use Tatsumaki::Error;
use Tatsumaki::Application;

my %streams;
my %listeners;
my $server = '';

# javascriptのメインループから呼ばれるハンドラ
package StreamWriter;
use base qw(Tatsumaki::Handler);
use AnySan;
use AnySan::Provider::IRC;
use Tatsumaki::MessageQueue;
use Encode;
use DateTime;
__PACKAGE__->asynchronous(1);

sub get {
    my $self = shift;
    my ($channel, $nickname) = @_;

    my $key = $channel . $nickname;

    $self->response->content_type('text/plain');

    my $mq = Tatsumaki::MessageQueue->instance($channel);

    $streams{ $channel }{ $nickname } ||=
        irc $server, nickname => $nickname, channels => { '#' . $channel => {} };

    $listeners{ $channel }{ $nickname } ||=
        AnySan->register_listener( $nickname => {
            cb => sub {
                my $receive = shift;
                my $now = DateTime->now( time_zone => 'Asia/Tokyo' );
                $mq->publish({
                    type     => 'messages',
                    nickname => $receive->from_nickname,
                    time     => $now->strftime('%H:%M'),
                    message  => decode_utf8($receive->message),
                });

                if ( $receive->message =~ /^$nickname / ) {
                    my $response = 'Hello! ' . $receive->from_nickname;
                    $streams{ $channel }{ $nickname }->send_message($response, channel => '#' . $channel);
                    $mq->publish({
                        type     => 'messages',
                        nickname => $nickname,
                        time     => $now->strftime('%H:%M'),
                        message  => decode_utf8($response),
                    });
                }
            }
        });

    $mq->poll_once(
        $key,
        sub {
            my @events = @_;
            $self->write( \@events );
            $self->finish;
        }
    );
}


# Post
package PostHandler;
use base qw(Tatsumaki::Handler);
use Data::Dumper;
use Encode;

sub post {
    my ($self, $channel, $nickname) = @_;

    my $v = $self->request->parameters;
    my $text = $v->{text};
    my $mq = Tatsumaki::MessageQueue->instance($channel);
    my $now = DateTime->now( time_zone => 'Asia/Tokyo' );
    $mq->publish({
        type     => 'messages',
        nickname => $nickname,
        time     => $now->strftime('%H:%M'),
        message  => decode_utf8($text),
    });

    $streams{ $channel }{ $nickname }->send_message($text, channel => '#' . $channel);
}


# 表示部
package MainHandler;
use base qw(Tatsumaki::Handler);


sub get {
    my ($self) = @_;
    $self->render('index.html');
}


# メイン
package main;
use File::Basename;

my $re = '[\w\.\-]+';
my $app = Tatsumaki::Application->new([
    "/stream/($re)/($re)" => 'StreamWriter',
    "/post/($re)/($re)"   => 'PostHandler',
    "/room/($re)/($re)"   => 'MainHandler',
]);

$app->template_path(dirname(__FILE__) . '/templates');
$app->static_path(dirname(__FILE__) . '/static');

$app;
