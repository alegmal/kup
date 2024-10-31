# kup (Kubernetes UPgrade)

### Why kup? What's the use case?

* You want to upgrade your kubernetes cluster and you dont want to find out you forgot to update deprecated apiVersion after the upgrade... oopsie!
* You have a cluster(s) with a lot of different workloads (deployments, crons, jobs...) and you cant imagine yourself kubectling through all that on all environments
* Workloads come from many different repositories from times when company was ruled by Roman empire
* You want to quickly identify what objects deployed in your cluster need API update
* You don't want to install and configure 3rd party tool even though it will look cool in your CV

### Have you overlooked kubent and pluto?...

* kubent: https://github.com/doitintl/kube-no-trouble
* pluto: https://github.com/FairwindsOps/pluto

Great tools, great tools... they have one problem though: they look at the wrong place! 

...and its not their fault. 

If you dig a bit you'll see that these tools don't actually look at apiVersion of objects as you would expect. These tools check for value of `kubectl.kubernetes.io/last-applied-configuration` annotation and this is a problem.

Why is this a problem? Well.. the problem is that in most cases i've seen this annotation is created when you first create object and thats it. It does not updated when you update these objects unless you re-create them or do another extra step or two. There are cases when you don't even have this annotation.

This means your HPA could be on `autoscaling/v2` but your annotation is telling pluto and kubent its using `autoscaling/v2beta2` back from the day of creation and you get a lot of false positives.

You can see in official pluto documentation that they're address this issue: https://pluto.docs.fairwinds.com/faq/#why-api-is-version-check-on-a-live-cluster-using-the-last-applied-configuration-annotation-not-reliable

### __*I'm confused... why don't they just look at apiVersion lol?*__

This what got me to write this simple bash script!

Apparently, due to how clients and kubernetes servers communicate, there is no apiVersion or kind in object's information when you get it through client. Here you can read a bit more about it: https://github.com/kubernetes/kubernetes/pull/127361#issuecomment-2353199198

```
Thanks for the PR, but I don't think this is the right layer to try to fix #80609 at.

There are four ways the API server returns serializations of typed objects:

1. individual return from a Get request (currently does include apiVersion/kind in the serialized form)
2. item in a list request (currently does not include apiVersion/kind in the individual items, just the parent list)
3. response from a write request (currently does include apiVersion/kind in the serialized form)
4. item in a watch event (currently does include apiVersion/kind in the serialized form)

On the client side, the decoder deserializes into a typed object, and currently forcibly clears the apiVersion/kind when doing so (because the type information is tied to the go type). That collapses cases 1, 3, and 4 to be consistent with case 2.

To make GVK be consistently populated when reading from the server, we would have to:

1. modify the server to insert apiVersion/kind into every item when returning a list response (case 2), which has some performance implications we haven't reasoned through yet
2. AND adjust the client to stop clearing apiVersion/kind when decoding into a typed versioned object
```


I believe it will be figured out in the future and pluto / kubent will have a flag or default behavior to check for apiVersion instead of last-applied annotation. But for now you have following options:

* `./kup.sh` and thats it - either you have things to update or you're good to go
* helm dry run to generate your templates and run them through pluto for example (what if you have many repositories?)
* make sure your last applied annotation exists and is always up to date
* enforce custom annotation on all object that is always up to date with actual apiVersion and now you can specify it to kubent using `--additional-annotation` (haven't tested it - https://github.com/doitintl/kube-no-trouble?tab=readme-ov-file#arguments)
* ??


# Contribution
Think you can make it better and more useful? Nice! :) send a PR!

...or just <u>__click this damn star!__</u> 

Thank you for coming to my TED speech, come again!

# ksight
Kubernetes upgrading insights

TODO or NOT-TODO: a configurable script or something for easy version compatibility check of common kubernetes installations vs kubernetes version (kube-state-metrics, keda, karpenter...)

... maybe just merge it in kup? idk