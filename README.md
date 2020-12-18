# WIP CouDB adapter
Demo proyect to design a viable couchdb adapter for ecto.
Currently it can do inserts, get  and simple queries

* `Sis.Repo.insert %User{}`
* `Sis.Repo.get User, "ID"`
* `Sis.Repo.all from u in User, where: u.first_name == "Juan" and u.last_name == "Perez", select: %{first_name: u.first_name}`

Still deciding if the adapter should handle basic Mango indexes for doing where queries. I found easy to do it for `and` concatenations.
But is imposible or very hard for `or` chains, for `or` chains though, doing a `MapView` will work pretty fast.

Maybe I will just do a generator so ona dding a Repo it will add the views and indexes... yeah I like this last...
