# todo_list

An example of a todo app that stores data in Ledger.

To build, use the following packages:

```
--with-base topaz/packages/examples:misc \
--with topaz/packages/tests:dart_unittests
```

To run, enter "todo_list" in the workstation ask box, wait for suggestions to
show up, and click on the "todo_list".

To run tests, make sure you build in debug, and then: `fx run-host-tests todo_list_test`