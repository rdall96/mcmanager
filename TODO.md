# TODO

## MVP
- All the work for server queries was useless - the `Network` library doesn't work on linux yet :-(
- Monitor server start process to properly set the `running` status
- Fix bug with server logs not being complete
- Auth token singing with private key

## Ideas

**Permissions**

User permissions to limit service functionality, discord style. Ideally it's a static set of permissions applied to all users where each field is a boolean (i.e.: VIEW_SETTINGS will determine if a user can see the MCManager settings).

Below is a draft of the permissions we plan on adding to MCManager. The name is the key name in the database, and the default value is the value that will be applied to all newly created users.

| Permission Name    | Default Value |
| ------------------ | ------------- |
| VIEW_SETTINGS      | 1             |
| EDIT_SETTINGS      | 0             |

| CREATE_USERS       | 0             |
| VIEW_USERS         | 1             |
| USER_PERMISSIONS   | 0             |

| CREATE_EDIT_SERVER | 0             |
| SERVER_INFO        | 1             |
| SERVER_METRICS     | 0             |
| SERVER_CONFIG      | 0             |
| SERVER_EXECUTION   | 1             |
| SERVER_LOGS        | 0             |
| SERVER_COMMANDS    | 0             |

Each set of permissions will be represented by an object like the following.
```swift
struct Permissions {
    var viewSettings: Bool
    var editSettings: Bool
    var createUsers: Bool
    var viewUsers: Bool
    // and so on...
}
```

This list of permissions will be assigned to a `UserRole` with the following schema:
```swift
struct UserRole {
    /// id of the role (required by the database)
    let id: UUID
    /// name of the role publicly visible to everyone
    let name: String
    /// list of permissions that apply to this group
    let permissions: Permissions
}
```

Each `User` can be assigned a role in order to represent their permissions:
```swift
extension User {
    var role: UUID
}
```

APIs:
- GET /roles, list of roles
- POST /roles, create a new role
- GET /roles/<role_id>, info about a role
- PUT /roles/<role_id>, edit a role


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
