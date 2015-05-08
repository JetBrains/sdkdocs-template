# SDK Docs Template

This repo is intended to make it easy to setup and manage an SDK documentation site for JetBrains products. It should be included as a submodule of the documentation repo, and is intended to hide as much of the scripting away from the documentation repo as possible.

Once this repo has been included in the documentation repo, the documentation repo only needs define a simple `Rakefile` and minimal `_config.yml` file, and everything else is handled automatically. Building and running the site is then as simple as:

```
rake preview
```

## How to add to a site

Jekyll requires Ruby, so make sure Ruby is installed. This repo makes use of [Bundler](http://bundler.io) to manage Ruby gem dependencies, installing the gems locally to prevent the need for installing globally.

1. Install Bundler - `gem install bundler`.
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
    * Runs `bundle install --path sdkdocs-template/_vendor/bundle`, which tells Bundler to create a local copy of the gems specified in the `Gemfile`. The gems are installed to `sdkdocs-template/_vendor/bundle`, which is excluded from source control.
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

    The `_site` folder is the generated site that is ready to be tested and deployed, and the `_includes` folder is unfortunately a Jekyll artifact that can't be redirected to another location. It can be safely ignored while working on the documentation. The `.bundle` folder contains configuration details for Bundler, and shouldn't be committed.
7. Commit the new files to source control - `Gemfile`, `Gemfile.lock`, `Rakefile`, `_config.yml` and `.gitmodules` and `sdkdocs-template`.

## How to build and test the site

To build and test the site, simply run `rake preview`. This will build the site and host it, using the config provided. The URL of the hosted site is displayed on the screen, and depends on the `baseurl` field defined in `_config.yml`.

When building the site, all files in the documentation repo (excluding `Rakefile`, `_includes` and the `sdkdocs-template` folder) are copied to the output `_site` folder. Markdown files are automatically converted to HTML, but only if they being with a YAML header. In other words, to convert a `.md` file to HTML, it should look like:

```md
---
---

# Introduction

Lorem ipsum...
```

The two lines at the top of the file are the markers of the YAML "front matter". Fields can be added in between these markers, and are used when generating the HTML. Typically, this header will be empty, although it is required by Jekyll (if omitted, the file isn't converted).

However, you can specify redirects in the YAML header, which is useful when renaming or moving files, and for creating a redirect from `/` to the `README.md` file. See below for details.

## README.md

The documentation site should contain a `README.md` file, which will be used as an introduction page, and should be the first page of the documentation site. It will also be displayed by GitHub when browsing the source. It is a good idea to set up a redirect from `index.html` in the YAML header for the `README.md` file. Something like:

```md
---
redirect_from:
  - /index.html
---

# Introduction

Lorem ipsum...
```

## CONTRIBUTING.md

The `CONTRIBUTING.md` file should provide information on how to contribute, including building and running the repo. Ideally, this will be:

* Clone
* Update submodules
    * `git submodule init`
    * `git submodule update`
* Install Ruby and `gem install bundler`
* `rake bootstrap`
* `rake preview`

## Creating the Table of Contents

The table of contents is generated from the `_SUMMARY.md` file. It is a simple markdown list, with each item in the list being a link to another markdown page, either in the root folder, or sub-folders. The list can have nested items, which will be displayed as child items in the table of contents.

```md
# Summary

* [Introduction](README.md)
* [About This Guide](Intro/About.md)
    * [Key Topics](Intro/KeyTopics.md)
```

The contents can be split into "parts" by separating the list into several lists, each with a level 2 heading (`##`).

```md
# Summary

* [Introduction](README.md)
* [About This Guide](Intro/About.md)
    * [Key Topics](Intro/KeyTopics.md)

## Part I - Extending the Platform
* [Getting Started](Docs/GettingStarted.md)
* ...
```

If a node doesn't have a link, but is just plain text, it will still appear in the table of contents, but will be greyed out and not clickable. It acts like a placeholder for a documentation item. This is useful to keep track of what should be documented, but hasn't yet, and can be useful to show readers that the topic exists, but isn't yet documented.

## Creating pages

A page is simply a markdown file, beginning with a YAML header. If the file does not have a YAML header, it won't get converted into HTML.

### Redirects

The documentation site is set up to include the `jekyll-redirect-from` plugin, which will generate "dummy" pages that automatically redirect to a given page. For example, to specify that the `index.html` page will be generated to redirect to `README.md`, the `README.md` file should include the following in the YAML header:

```md
---
redirect_from:
  - /index.html
---

# Introduction

Lorem ipsum...
```

This will create an `index.html` file that will automatically redirect to the generated `README.html` file. This is very useful to allow the site URL to automatically show the `README.html` file - `http://localhost:4001/foo-test/` will try to load `index.html`, which will automatically redirect to `README.html`.

It is also useful to redirect when renaming or moving files. Multiple redirects can be added to the YAML header.

### Page Table of Contents

The site is configured to use the [Kramdown Markdown converter](), which adds some extra features, such as "attribute lists", which can apply attributes to the generated elements.

One useful attribute is `{:toc}`, which can be applied to a list item, which will get replaced with a list of links to header items. E.g. the following list item will be replaced by links to all of the header items in the page:

```md
* Dummy list item
{:toc}
```

Further Kramdown features are described on the [converter page](http://kramdown.gettalong.org/converter/html.html), and attribute lists are described on the [syntax page](http://kramdown.gettalong.org/syntax.html). Note that source code formatting is configured to use GitHub Flavoured Mardown and "code fences", see below.

### Liquid tags and filters

Jekyll uses the Liquid templating language to process files. This means standard Liquid tags and filters are available. There should be little need to use them however, as the Markdown format is already quite rich. See the [Jekyll site](http://jekyllrb.com/docs/templates/) for more details.

### Source code

Source code can be represented by using GitHub Flavoured Markdown code fences, which are three back ticks

    ```
    // Source code goes here...
    ```

Syntax highlighting can be applied by specifying the language after the first set of ticks:

    ```csharp
    // Some C# code
    ```

    ```java
    // Some Java code
    ```

Here is the list of [supported languages](https://github.com/github/linguist/blob/master/lib/linguist/languages.yml).

The site is also configured to highlight a range of files in the source code, by specifying `{start-end}` which is the start and end line of the highlighting:

    ```java{2-3}
    // Not highlighted
    // Highlighted
    // Highlighted
    // Not highlighted
    ```

### Notes and callouts

Notes and callouts can be specified using the blockquote syntax. The converter will look at the first following word to see if it is bold. If so, it will apply that as a callout style. For example:

    > *NOTE* This is a note

Will be displayed as a callout, styled as a "note". The other styles available for callouts are "note", "warning", "tip" and "todo".:w


### Linking to headers

When a Markdown header is converted to an HTML header, it is assigned an ID, so it can be linked, e.g. `## Introduction` will get the ID of `introduction`, and can be linked either in the same page `[click here](#introduction)` or cross page `[click here](page.html#introduction)`.

## Bundler

The Rake files hide away any Bundler details, but if you add any 

## Submodules

This repo is supposed to be used as a submodule, and contains a submodule to the private `webhelp-template` repo (`webhelp-template` is the JS and CSS for the documentation site, `sdkdocs-template` provides scripts to make it easier to set up and maintain a documentation site using the webhelp template).

Adding a submodule is done by something like:

    ```
    git submodule add git@git.labs.intellij.net:sites/webhelp-template.git webhelp-template
    ```

This will create a `.gitmodules` file, register a submodule in the `webhelp-template` folder, and check out the files. (Note that when a repo is added as a submodule, it doesn't get a `.git` folder, but instead gets a `.git` file that points to the location of the `.git` folder.

A submodule can be updated using normal git commands such as `git pull`. It can be switched to a different branch using `git checkout`, and any changes to the currently checked out revision need to be committed back into the main repo, as normal git commands. It is initially cloned at a specific revision, and not as part of a branch.update

Note that this repo currently uses the `resharper-devguide` of the `webhelp-template` submodule, which contains minor updates over the default webhelp template (the ability to have "placeholder" nodes in the table of contents).
