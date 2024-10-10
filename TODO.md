# TODO

## MVP
- All the work for server queries was useless - the `Network` library doesn't work on linux yet :-(

## Ideas

**Groups**

Groups will be a great feature to subdivide users and servers alike. A server can only be part of one group, while users cna be part of multiple groups.

Data model:
```swift
struct Group {
    /// id of the group (to reference in other data models)
    let id: UUID
    /// Name of the group - publicly visible
    let name: String
    /// List of servers belonging to this group
    let servers: [UUID]
    /// List of users belonging to this group
    let users: [UUID]
}
```

Groups are like a flat folder structure for servers, and users can be assigned to multiple groups to indicate what they have access to.

`UserRoles` will also play a part, since a user can have different roles across different groups:
```swift
extension User {
    /// Roles are now index by group
    var roles: [UUID:UUID]
}
```

To allow for backwards compatibility a `Default` group will be created for all servers and users. This group will be treated as a service wide group that all users have access to, and servers without a group will appear here.

APIs:
- GET /groups, list all groups
- POST /groups, create a group
- GET /groups/<group_id>, info about a group, servers, and users
- PUT /groups/<group_id>, update a group
- POST /users/<user_id>/group/<group_id>/role/<role_id>, set the role to the user for a specific group
- DELETE /users/<user_id>/group/<group_id>/role/<role_id>, remove the role to the user for a specific group

New Permissions:
- VIEW_GROUPS
- CREATE_GROUPS
- 
