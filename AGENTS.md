This is an open source music player that should work on Linux, macOS, Windows, Android, and iOS.

Make sure all tests pass. If they don't, fix them. You should also add new tests when needed.

# Creating an MR

1. Only run this if the GitLab account has write permission to the repo.
   1. Create the MR.
   2. If the authed GitLab account is HttpAnimations and the change is an actual code change (not just a simple string replacement, md update, GitHub Action tweak, or similar small job), trigger a CodeRabbit review by sending `@coderabbitai review` as a comment in the MR.
   3. Once CodeRabbit responds, make sure everything is good and fix the issues it raised. It may add new comments to the thread after you fix the first issues, so reread it.
   4. This repo is mirrored to GitHub at https://github.com/openlyst/doudou. It takes about 5 minutes to sync, so make sure all jobs pass, including testing.
