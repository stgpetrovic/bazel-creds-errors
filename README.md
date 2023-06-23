# Suggestion for improvement

When using remote build/remote caching, bazel can authenticates using a
`--google_credentials=path/to/creds.json` flag to point to a JSON file
containing credentials to authenticate with gcloud.

There are a two important error scenarios here:

* file does not exist, which gets a nice error:

  ERROR: Could not open auth credentials file '/tmp/credentials.309EF4':
  /tmp/credentials.309EF4 (No such file or directory)
  ERROR: Error initializing RemoteModule

* file is not a valid JSON file, which crashes bazel server with a top level
    exception (IllegalArgumentException), and the client just dies silently:

```
  crash {
    causes {
      throwable_class: "java.lang.IllegalArgumentException"
      message: "no JSON input found"
      stack_trace: "com.google.common.base.Preconditions.checkArgument(Preconditions.java:145)"
      stack_trace: "com.google.api.client.util.Preconditions.checkArgument(Preconditions.java:47)"
      stack_trace: "com.google.api.client.json.JsonParser.startParsing(JsonParser.java:215)"
      stack_trace: "com.google.api.client.json.JsonParser.parse(JsonParser.java:358)"
      stack_trace: "com.google.api.client.json.JsonParser.parse(JsonParser.java:335)"
      stack_trace: "com.google.api.client.json.JsonObjectParser.parseAndClose(JsonObjectParser.java:79)"
      stack_trace: "com.google.api.client.json.JsonObjectParser.parseAndClose(JsonObjectParser.java:73)"
      stack_trace: "com.google.auth.oauth2.GoogleCredentials.fromStream(GoogleCredentials.java:162)"
      stack_trace: "com.google.auth.oauth2.GoogleCredentials.fromStream(GoogleCredentials.java:139)"
      stack_trace: "com.google.devtools.build.lib.authandtls.GoogleAuthUtils.newGoogleCredentialsFromFile(GoogleAuthUtils.java:328)"
      stack_trace: "com.google.devtools.build.lib.authandtls.GoogleAuthUtils.newGoogleCredentials(GoogleAuthUtils.java:300)"
      stack_trace: "com.google.devtools.build.lib.authandtls.GoogleAuthUtils.newCredentials(GoogleAuthUtils.java:265)"
      stack_trace: "com.google.devtools.build.lib.remote.RemoteModule.createCredentials(RemoteModule.java:1099)"
      stack_trace: "com.google.devtools.build.lib.remote.RemoteModule.beforeCommand(RemoteModule.java:359)"
      stack_trace: "com.google.devtools.build.lib.runtime.BlazeCommandDispatcher.execExclusively(BlazeCommandDispatcher.java:395)"
      stack_trace: "com.google.devtools.build.lib.runtime.BlazeCommandDispatcher.exec(BlazeCommandDispatcher.java:240)"
      stack_trace: "com.google.devtools.build.lib.server.GrpcServerImpl.executeCommand(GrpcServerImpl.java:550)"
      stack_trace: "com.google.devtools.build.lib.server.GrpcServerImpl.lambda$run$1(GrpcServerImpl.java:614)"
      stack_trace: "io.grpc.Context$1.run(Context.java:566)"
      stack_trace: "java.base/java.util.concurrent.ThreadPoolExecutor.runWorker(Unknown Source)"
      stack_trace: "java.base/java.util.concurrent.ThreadPoolExecutor$Worker.run(Unknown Source)"
      stack_trace: "java.base/java.lang.Thread.run(Unknown Source)"
    }
  }
```

```
goranpetrovic:~/bazel-testing-stuff/mvp$ bazel build //:main --google_credentials=/tmp/invalid_json_credentials.json --remote_cache=grpcs://remotebuildexecution.googleapis.com
// NO OUTPUT
goranpetrovic:~/bazel-testing-stuff/mvp$ echo $?
37
```

This is kind of nasty, and there should be an error surfaced here that makes it
easy to fix this, e.g. with the following patch to bazel:

```
diff --git i/src/main/java/com/google/devtools/build/lib/authandtls/GoogleAuthUtils.java w/src/main/java/com/google/devtools/build/lib/authandtls/GoogleAuthUtils.java
index 409263929c..215ee60537 100644
--- i/src/main/java/com/google/devtools/build/lib/authandtls/GoogleAuthUtils.java
+++ w/src/main/java/com/google/devtools/build/lib/authandtls/GoogleAuthUtils.java
@@ -330,7 +330,7 @@ public final class GoogleAuthUtils {
         creds = creds.createScoped(authScopes);
       }
       return creds;
-    } catch (IOException e) {
+    } catch (IllegalArgumentException | IOException e) {
       String message = "Failed to init auth credentials: " + e.getMessage();
       throw new IOException(message, e);
     }
```

it already looks better:
```
goranpetrovic:~/bazel-testing-stuff/mvp$ ../bazel/bazel-bin/src/bazel-dev build //:main --google_credentials=/tmp/invalid_json_credentials.json --remote_cache=grpcs://remotebuildexecution.googleapis.com
INFO: Invocation ID: f64c5f87-3789-425d-82e5-8075f895d791
ERROR: Failed to init auth credentials: no JSON input found
ERROR: Error initializing RemoteModule
goranpetrovic:~/bazel-testing-stuff/mvp$ echo $?
2
```

Cheers!
