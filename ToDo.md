### Adding Items

```text
When all existing checklist items are loaded (given there are any)
Then an empty TextField is added after any other items in the list
And no "add new item" button is displayed
```

```text
Given User has entered content into the TextField
When they submit the data
Then the entered data is persisted to the checklist (and database)
```

```text
When User submits while the TextField is empty
Then nothing is persisted to the database
And a notice is displayed that items can't be empty
```

### Editing Items

```text
ToDo
```

### Deleting Items

```text
ToDo
```