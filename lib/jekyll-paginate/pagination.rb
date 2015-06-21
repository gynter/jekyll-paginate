module Jekyll
  module Paginate
    class Pagination < Generator
      # This generator is safe from arbitrary code execution.
      safe true

      # This generator should be passive with regard to its execution
      priority :lowest

      # Generate paginated pages if necessary.
      #
      # site - The Site.
      #
      # Returns nothing.
      def generate(site)
        # Convert string paginate_path to array, for backwards
        # compatibility.
        if site.config['paginate_path'].instance_of? String
            Jekyll.logger.warn "Pagination:", "paginate_path is as String, " +
            "but should be an Array, converting it for backwards compatibility, "+
            "but make sure You update the config"
            site.config['paginate_path'] = [site.config['paginate_path']]
        end

        site.config['paginate_path'].each_with_index do |paginate_path, index|
          if Pager.pagination_enabled?(site)
            if template = self.class.template_page(site, index)
              paginate(site, index, template)
            else
              Jekyll.logger.warn "Pagination:", "Pagination is enabled, but I couldn't find " +
              "an index.html page to use as the pagination template. Skipping pagination."
            end
          end
        end
      end

      # Paginates the blog's posts. Renders the index.html file into paginated
      # directories, e.g.: page2/index.html, page3/index.html, etc and adds more
      # site-wide data.
      #
      # site  - The Site.
      # index - index in the paginate_path list
      # page  - The index.html Page that requires pagination.
      #
      # {"paginator" => { "page" => <Number>,
      #                   "per_page" => <Number>,
      #                   "posts" => [<Post>],
      #                   "total_posts" => <Number>,
      #                   "total_pages" => <Number>,
      #                   "previous_page" => <Number>,
      #                   "next_page" => <Number> }}
      def paginate(site, index, page)
        site_posts = []
        all_posts = site.site_payload['site']['posts'].reject { |post| post['hidden'] }

        # Filter all posts with available filters.
        if site.config['paginate_filter']
          if !site.config['paginate_filter'][index].nil?
            all_posts.each do |post|
              filter_name = site.config['paginate_filter'][index]['name']
              filter_value = site.config['paginate_filter'][index]['value']
              value = post[filter_name]

              if value
                if filter_value.instance_of? Array
                  if filter_value.include? value
                    site_posts.push(post)
                  end
                else
                  if filter_value == value
                    site_posts.push(post)
                  end
                end
              end
            end
          end
        end

        if site_posts.empty?
          site_posts = all_posts
        end

        pages = Pager.calculate_pages(site_posts, site.config['paginate'].to_i)
        (1..pages).each do |num_page|
          pager = Pager.new(site, index, num_page, site_posts, pages)
          if num_page > 1
            newpage = Page.new(site, site.source, page.dir, page.name)
            newpage.pager = pager
            newpage.dir = Pager.paginate_path(site, index, num_page)
            site.pages << newpage
          else
            page.pager = pager
          end
        end
      end

      # Static: Fetch the URL of the template page. Used to determine the
      #         path to the first pager in the series.
      #
      # site  - the Jekyll::Site object
      # index - index in the paginate_path list
      #
      # Returns the url of the template page
      def self.first_page_url(site, index)
        if page = Pagination.template_page(site, index)
          page.url
        else
          nil
        end
      end

      # Public: Find the Jekyll::Page which will act as the pager template
      #
      # site  - the Jekyll::Site object
      # index - index in the paginate_path list
      #
      # Returns the Jekyll::Page which will act as the pager template
      def self.template_page(site, index)
        site.pages.select do |page|
          Pager.pagination_candidate?(site.config, index, page)
        end.sort do |one, two|
          two.path.size <=> one.path.size
        end.first
      end

    end
  end
end
