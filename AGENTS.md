All changes must follow these rules.

1. Do not leak any API keys or JKS keys at all. (Note that a YTM API key is present in the codebase; this is not a real API key but just a string to ensure that YouTube gives a checkmark on API requests.)
2. Do not write god files; refactor stuff if you have to.
3. Do not use em dashes and other AI garbage writing; no one wants to read AI slop.
4. Do not run the app (e.g. flutter run -d linux). The developer will do this.
5. Write tests for EVERY new thing you do. Any code change should be testable no matter how small it is; write the test. Make sure tests are not created just to pass; they should test the actual changes. EXCEPT for non-code changes: editing a md file or license file or anything that is not an actual code change, no test is needed and should not be written.
6. Ensure all tests pass after any change.
7. When opening a merge request, in the body include what model, provider and the harness used to create the merge request. If the code was human made then state "Created by human, PR created with ...."
8. When opening a new merge request make sure to update the changelog.md file for the change you did UNLESS it's not a code change. Make sure it is listed under the same version in the pubspec version.
