# frozen_string_literal: true

require 'colorize'
require 'highline'
require 'yaml'
require 'octokit'

class Agent
  CLI = HighLine.new

  MAX_RETRY = 3
  LABELS = 'labels.yaml'.freeze
  PROJECT = 'project.yaml'.freeze

  def initialize(logger)
    @logger = logger
    @logger.formatter \
      = proc { |severity, _, _, message| "#{severity}: #{message}\n".green }
  end

  def run
    set_resource_folder

    connect

    choose_start_point

    repo = if @start <= 1
             create_private_repo
           else
             CLI.ask('repo for CTF (username/repo)? ')
           end

    setup_labels(repo) if @start <= 2
    setup_project(repo) if @start <= 3
  end

  private

  def set_resource_folder
    @res = CLI.ask('resource folder? ') { |q| q.default = 'templates' }
  end

  def label_file
    "#{@res}/#{LABELS}"
  end

  def project_file
    "#{@res}/#{PROJECT}"
  end

  def connect
    retries ||= 0

    @username = CLI.ask 'username? '
    @password = CLI.ask('password? ') { |q| q.echo = 'x' }

    @client = Octokit::Client.new(login: @username, password: @password)

    # Try
    @logger.info "Logged in user #{@client.user.login}"
  rescue Octokit::Unauthorized
    @logger.error 'Wrong username or password'

    retry if (retries += 1) < MAX_RETRY

    raise
  end

  def choose_start_point
    CLI.choose do |menu|
      menu.header = 'Start with creating'

      menu.choice(:repository) { @start = 1 }
      menu.choice(:labels) { @start = 2 }
      menu.choice(:project) { @start = 3 }

      menu.prompt = 'from where? '
    end
  end

  def create_private_repo
    repo = CLI.ask 'new repo for CTF? '
    opts = { private: true }
    @logger.info "Creating #{repo}"
    @client.create_repo(repo, opts)
    "#{@username}/#{repo}"
  end

  def setup_labels(repo)
    delete_old_labels! repo
    labels = YAML.load_file label_file
    add_labels(repo, labels)
  end

  def delete_old_labels!(repo)
    @logger.info "Deleting old labels in #{repo}..."
    @client.labels(repo).each do |label|
      @logger.info "Deleting a label (#{label.name})..."
      @client.delete_label!(repo, label.name)
    end
  end

  def add_labels(repo, labels)
    labels.each do |name, color|
      @logger.info "Adding a new label (#{name}: #{color})..."
      @client.add_label(repo, name.to_s, color)
    end
  end

  def setup_project(repo)
    project = YAML.load_file project_file
    new_project = create_project(repo, project['name'])
    add_project_columns(new_project.id, project['columns'])
  end

  def create_project(repo, name)
    @logger.info "Creating a new project (#{name})..."
    @client.create_project(repo, name)
  end

  def add_project_columns(id, columns)
    columns.each do |_, column|
      @logger.info "Adding a new column (#{column})..."
      @client.create_project_column(id, column)
    end
  end
end
