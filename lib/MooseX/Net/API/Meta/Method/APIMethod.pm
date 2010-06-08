package MooseX::Net::API::Meta::Method::APIMethod;

# ABSTRACT: declare API method

use Moose::Role;
use MooseX::Net::API::Error;
use MooseX::Net::API::Meta::Method;
use MooseX::Types::Moose qw/Str ArrayRef/;

has local_net_api_methods => (
    traits     => ['Array'],
    is         => 'rw',
    isa        => ArrayRef [Str],
    required   => 1,
    default    => sub { [] },
    auto_deref => 1,
    handles    => {
        _find_net_api_method_by_name => 'first',
        _add_net_api_method          => 'push',
        get_all_net_api_methods      => 'elements',
    },
);

sub find_net_api_method_by_name {
    my ($meta, $name) = @_;
    my $method_name = $meta->_find_net_api_method_by_name(sub{/$name/});
    return unless $method_name;
    my $method = $meta->find_method_by_name($method_name);
    if ($method->isa('Class::MOP::Method::Wrapped')) {
        return $method->get_original_method;
    }else{
        return $method;
    }
}

sub remove_net_api_method {
    my ($meta, $name) = @_;
    my @methods = grep { !/$name/ } $meta->get_all_api_methods;
    $meta->local_api_methods(\@methods);
    $meta->remove_method($name);
}

before add_net_api_method => sub {
    my ($meta, $name) = @_;
    if ($meta->find_net_api_method_by_name(sub {/^$name$/})) {
        die MooseX::Net::API::Error->new(
            reason => "method '$name' is already declared in " . $meta->name);
    }
};

sub add_net_api_method {
    my ($meta, $name, %options) = @_;

    # XXX accept blessed method ?

    my $code = delete $options{code};

    $meta->add_method(
        $name,
        MooseX::Net::API::Meta::Method->wrap(
            name         => $name,
            package_name => $meta->name,
            body         => $code,
            %options
        ),
    );
    $meta->_add_net_api_method($name);
}

after add_net_api_method => sub {
    my ($meta, $name) = @_;
    $meta->add_before_method_modifier(
        $name,
        sub {
            my $self = shift;
            die MooseX::Net::API::Error->new(
                reason => "'api_base_url' have not been defined")
              unless $self->api_base_url;
        }
    );
};

1;

=head1 SYNOPSIS

    my $api_client = MyAPI->new;

    my @methods    = $api_client->meta->get_all_api_methods();

    my $method     = $api_client->meta->find_net_api_method_by_name('users');

    $api_client->meta->remove_net_api_method($method);

    $api_client->meta->add_net_api_method('users', sub {...},
        description => 'this method does...',);

=head1 DESCRIPTION

=method get_all_net_api_methods

Return a list of net api methods

=method find_net_api_method_by_name

Return a net api method

=method remove_net_api_method

Remove a net api method

=method add_net_api_method

Add a net api method
