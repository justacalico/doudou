All changes must follow these rules.

1. Do not leak any api keys or jks keys at all. (note their is a harcoded api key for ytm that api key is not a actural real api key)
2. Do not write god files refactor stuff if you have to.
3. Do not use em dashes and other ai grabage writing no one wants to read AI Slop.
4. Do not run the app eg. flutter run -d linux The devloper will do this.
5. Write tests for EVERY new thing you do any code change should be testable no matter how small it is write the test. Make sure tests are created just to pass they should test the actural changes. EXPECT for non-code changes editing a md file or linaece file or anything that is not a actural code change no test is needed and should not be written.
6. Ensure all tests pass after any change.
7. When opening a merge request in the body include what model, provider and the harness used to create the merge request. If the code was human made then state "Created by human, PR created with ...."
8. When opening a new merge request make sure to update the changelog.md file for the change you did UNLESS its not a code change.
