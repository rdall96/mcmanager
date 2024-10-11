# TODO

- All the work for server queries was useless - the `Network` library doesn't work on linux yet :-(

## Ideas

### Groups

> Should groups be global (design below), or treated more as a preference per-user? i.e.: each user can create its own groups and assign servers to organize their dashboard

Groups will be a great feature to assign servers into folders. Groups are a standalone data model with APIs to fetch/create/edit/delete them.

**Data model:**
```swift
struct Group {
    /// id of the group (to reference in other data models)
    let id: UUID
    /// Name of the group - publicly visible
    let name: String
    /// List of servers belonging to this group
    let servers: [UUID]
}
```

**APIs:**
- GET /groups, list all groups
- POST /groups, create a group
- GET /groups/<group_id>, info about a group, servers, and users
- PUT /groups/<group_id>, update a group details
- DELETE /groups/<group_id>, delete a group (servers will persist)
- GET /groups/<group_id>/servers, list all the servers in a group
- PUT /groups/<group_id>/servers, add servers to a group

**New Permissions:**
- Manage groups (create/update/delete)
- Add servers to group
