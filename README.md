# SDK Docs Template

This repo is intended to make it easy to set up and manage an SDK documentation site for JetBrains products. It should be included as a submodule of the documentation repo, and is intended to hide as much of the scripting away from the documentation repo as possible.

Once this repo has been included in the documentation repo, the documentation repo only needs define a simple `Rakefile` and minimal `_config.yml` file, and everything else is handled automatically. Building and running the site is then as simple as:

```
rake preview
```

## How to clone and use an existing documentation site

Please see the [CONTRIBUTING-example.md](CONTRIBUTING-example.md) for instructions on building sites with this repo. (The `CONTRIBUTING-example.md` file is intended to be copied, edited and added to the documentation site. It contains all the information required for building a documentation site.)

## How to add to a new documentation site

Please refer to the [CONTRIBUTING-example.md](CONTRIBUTING-example.md) file for details on [setting up your environment](CONTRIBUTING-example.md#setting-up-your-environment), especially for setting up prerequisites.

To add the `sdkdocs-template` repo as a submodule for a new documentation site:

1. Ensure Bundler is installed - `gem install bundler`.
2. On Windows, ensure the `devkitvars.bat` file has been run in the current command prompt (e.g. `c:\tools\DevKit\devkitvars.bat`).
2. Add this repo as a submodule of your documentation site.

    ```
    git submodule add https://github.com/JetBrains/sdkdocs-template.git sdkdocs-template
    ```

    This will create a `.gitmodules` file in the root folder. This needs to be committed. Ensure that the `sdkdocs-template` folder is populated. If it isn't, run `git submodule init` and `git submodule update`.

3. Add a `Rakefile` to your documentation site. This simply includes the rake files defined in this `sdkdocs-template` repo, and overrides config used by the rake scripts and Jekyll. A good example is:

    ```ruby
    Rake.add_rakelib 'sdkdocs-template/rakelib'

    # Override the default CONFIG here
    CONFIG = {
      :source_dir => __dir__,
      :tmp_dir => "#{__dir__}/_tmp",
      :build_destination => '_site/',
      :preview_host => '0.0.0.0',
      :preview_port => 4001,
      :default_env => 'dev'
    }
    ```

4. Run `rake bootstrap` to set up the Jekyll environment. This will:
    * Create a `Gemfile` in the root directory, if it doesn't exist. The `Gemfile` will include `sdkdocs-template/bundler/Gemfile.defaults`, which lists the default gems required.
    * Runs `bundle install --path ~/.bundles/sdkdocs-template/_vendor/bundle`, which tells Bundler to create a local copy of the gems specified in the `Gemfile`. The gems are installed to `~/.bundles/sdkdocs-template/_vendor/bundle`.
    * If you wish to add further gems, add them to the `Gemfile` in the root folder, and run `bundle install`.
5. Add a `_config.yml` file to specify config for the Jekyll site. The `sdkdocs-template` includes a default config file, and this one can override anything in there. You can see what other values are available for overriding by looking at `sdkdocs-template/jekyll/_config-defaults.yml.erb` (the file is pre-processed before being used to fix some paths). A good example of the content you need to add to the documentation site:

    ```yaml
    ---
    product_name: Foo
    product_version: 1.0
    product_type: Web Help

    baseurl: /foo-test/
    ```

    * The `product_name` field is used for the name of the product being documented, and is required. The `product_version` field is optional, and specifies the version of the product, and is used, together with the product name, in the title of pages. The `product_type` field is displayed in the page and site titles, as well as the search placeholder. The idea of the product type is to change the default of "Web Help" to e.g. "DevGuide".
    * The `baseurl` field specifies the baseurl of the site, so that it can be hosted at a sub-folder, rather than at the root of a site. This is used to generate the full URLs of pages and links so that folders and sub-folders in the site will work correctly. If the final site is to be hosted at `jetbrains.com/resharper/devguide`, the `baseurl` should be `/resharper/devguide/`. It should end in a trailing slash.
6. Add the following to your `.gitignore` file:

    ```
    _includes/
    _site/
    .bundle/
    ```

    The `_site` folder is the generated site that is ready to be tested and deployed, and the `_includes` folder is unfortunately a Jekyll artifact that can't be redirected and hosted in the `sdkdocs-template` folder. It can be safely ignored while working on the documentation. The `.bundle` folder contains configuration details for Bundler, and shouldn't be committed.
7. Commit the new files to source control - `Gemfile`, `Gemfile.lock`, `Rakefile`, `_config.yml` and `.gitmodules` and `sdkdocs-template`.

## How to build and test the site

To build and test the site, simply run `rake preview`. This will build the site and host it, using the config provided. The URL of the hosted site is displayed on the screen, and depends on the `baseurl` field defined in `_config.yml`.

See [CONTRIBUTING-example.md] for more details.

## Submodules

This repo is supposed to be used as a submodule, and it also contains a submodule to the private `webhelp-template` repo (`webhelp-template` is the JS and CSS for the documentation site, `sdkdocs-template` provides scripts to make it easier to set up and maintain a documentation site using the webhelp template). The `webhelp-template` is currently closed source. The current plan is to make it open source, in which case, it is likely the two repos are merged.

Adding a submodule is done by something like:

    ```
    git submodule add git@git.labs.intellij.net:sites/webhelp-template.git webhelp-template
    ```

This will create a `.gitmodules` file, register a submodule in the `webhelp-template` folder, and check out the files. (Note that when a repo is added as a submodule, it doesn't get a `.git` folder, but instead gets a `.git` file that points to the location of the `.git` folder.

A submodule can be updated using normal git commands such as `git pull`. It can be switched to a different branch using `git checkout`, and any changes to the currently checked out revision need to be committed back into the main repo, as normal git commands. It is initially cloned at a specific revision, and not as part of a branch.update

Note that this repo currently uses the `resharper-devguide` branch of the `webhelp-template` submodule, which contains minor updates over the default webhelp template (e.g. the ability to have "placeholder" nodes in the table of contents).
