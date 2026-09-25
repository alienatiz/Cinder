# Contributing with pull requests

Submit pull requests to **`dev`** in [alienatiz/Cinder](https://github.com/alienatiz/Cinder).
Keep each pull request focused on one feature, fix, or documentation change.

1. **Create a working branch from the latest `dev`.** Use a fork you can push to, or a feature branch in this repository if you have write access.
2. **Make and commit the change.** Keep each completed change in a separate, coherent commit. Include related resources, tests, and documentation. Review the diff and exclude build output and private working files. Follow the [commit attribution rules](AUTHORS.md).
3. **Check your work.** Run the relevant checks in the [build guide](Docs/BUILDING.md). State which checks passed and which you could not run. For README changes, keep the English, Korean, and Japanese versions consistent.
4. **Push your working branch and open a pull request.** On GitHub, open **Pull requests → New pull request**. Set the base repository to `alienatiz/Cinder` and the base branch to **`dev`**. Select your working branch as the compare branch; use **compare across forks** when contributing from a fork.
5. **Describe the result.** Use a clear title and explain the problem, what changes for the user, and how you checked it. Include screenshots for visible UI changes and link related issues when applicable. Open a draft if the change is not ready for review.
6. **Address review feedback.** Push follow-up commits to the same branch, resolve discussions, and ensure required checks pass before requesting another review. Merging is handled through the repository's review process.

Pull requests should not introduce stable release tags or change the release
channel as part of an unrelated feature or fix.
