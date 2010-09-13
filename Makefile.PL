use inc::Module::Install;
name 'AnyEvent-FlashSocketPolicy';
all_from 'lib/AnyEvent/FlashSocketPolicy.pm';
readme_from 'lib/AnyEvent/FlashSocketPolicy.pm';
readme_markdown_from 'lib/AnyEvent/FlashSocketPolicy.pm';
readme_pod_from 'lib/AnyEvent/FlashSocketPolicy.pm';
githubmeta;

# requires '';

tests 't/*.t';
author_tests 'xt';

build_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
