
<div>

# createState method

</div>


<div>

1.  @[override](https://api.flutter.dev/flutter/dart-core/override-constant.html)

</div>

[[State](https://api.flutter.dev/flutter/widgets/State-class.html)[\<[[UserFeed](../../views_after_auth_screens_profile_user_feed/UserFeed-class.md)]\>]]



override




Creates the mutable state for this widget at a given location in the
tree.

Subclasses should override this method to return a newly created
instance of their associated
[State](https://api.flutter.dev/flutter/widgets/State-class.html)
subclass:

``` language-dart
@override
State<SomeWidget>  => ;
```

The framework can call this method multiple times over the lifetime of a
[StatefulWidget](https://api.flutter.dev/flutter/widgets/StatefulWidget-class.html).
For example, if the widget is inserted into the tree in multiple
locations, the framework will create a separate
[State](https://api.flutter.dev/flutter/widgets/State-class.html) object
for each location. Similarly, if the widget is removed from the tree and
later inserted into the tree again, the framework will call
[createState](../../views_after_auth_screens_profile_user_feed/UserFeed/createState.md)
again to create a fresh
[State](https://api.flutter.dev/flutter/widgets/State-class.html)
object, simplifying the lifecycle of
[State](https://api.flutter.dev/flutter/widgets/State-class.html)
objects.



## Implementation

``` language-dart
@override
State<UserFeed>  => ;
```







1.  [talawa](../../index.md)
2.  [user_feed](../../views_after_auth_screens_profile_user_feed/)
3.  [UserFeed](../../views_after_auth_screens_profile_user_feed/UserFeed-class.md)
4.  createState method

##### UserFeed class







