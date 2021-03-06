#!/usr/bin/osascript -l JavaScript
/*
 * Lists people from Contacts
 *
 * Requires one argument: the name of the group to pull people from.
 */
function run(argv) {
    let groupName = argv[0];
    if (groupName == null) {
        throw "No group specified as argument";
    }

    let contacts = Application('Contacts');
    let people = contacts.groups.byName(groupName).people;

    let ids = people.id();
    let names = people.name();
    let emails = people.emails.value();
    var i = 0;

    let result = ids.map(function(id) {
        return {
            id: id,
            name: names[i],
            email: emails[i++][0]
        }
    });

    return JSON.stringify(result);
}
