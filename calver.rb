#!/usr/bin/env ruby

require 'optparse'
require 'date'

options = {}

class Revision
  attr :year, :month, :revCount, :hotfix

  def initialize(revString)
    dots = revString.split(".").map { |s| s.to_i }
    @year = dots[0]
    @month = dots[1]
    @revCount = dots[2]
    @hotfix = dots[3]
  end

  def to_s
    ret = "#{@year.to_s.rjust(2,"0")}.#{@month.to_s.rjust(2,"0")}.#{@revCount}.#{@hotfix}"
    ret.chomp(".")
  end

  # next version is always yy.mm.revCount+1, truncating off hotfixes.
  # if the "next version" we're wanting is for a hotfix, we're going to
  # call Revision#hotfix
  def nextVersion
    newRevision(@year, @month, @revCount.nil? ? 1 : @revCount + 1)
  end

  def hotfix
    newRevision(@year, @month, @revCount, @hotfix.nil? ? 1 : @hotfix + 1)
  end

  def hotfix?
    ! @hotfix.nil?
  end

  def monthStart
    # hello year 2100
    n = (Date.new(2000 + @year,@month) >> 1)
    newRevision(n.year - 2000, n.month, 1)
  end

  def currentMonth
    "#{@year.to_s.rjust(2,"0")}.#{@month.to_s.rjust(2,"0")}"
  end

  def parentBranch(forceHotfix = false)
    if forceHotfix || hotfix?
      "#{@year.to_s.rjust(2,"0")}.#{@month.to_s.rjust(2,"0")}.#{@revCount}"
    else
      "#{@year.to_s.rjust(2,"0")}.#{@month.to_s.rjust(2,"0")}"
    end
  end

  protected
  def newRevision(year, month, revcount, hotfix=nil)
    return Revision.new([year,month,revcount,hotfix].flatten.join(".").chomp("."))
  end
end

MODES = [ 'help', 'hotfix', 'nextVersion', 'monthStart' ].freeze


OptionParser.new do |opts|
  opts.banner = "Usage: calver.rb [options]"

  opts.on("--mode=MODE") do |mode|
    if MODES.include?(mode)
      options.merge!({:mode => mode})
    else
      raise ArgumentError.new("Invalid Mode #{mode}, expecting one of #{MODES}")
    end
  end
  opts.on("--help") do |help|
    puts <<-EOF
CalVer for Git
Usage: #{__FILE__} --mode=<help|nextVersion|hotfix|monthStart> [previous version]

Generating the next version: #{__FILE__} --mode=nextVersion [previous version]

If the [previous version] is omitted, the first revision for the year and
month are used (eg #{Time.now.to_date.strftime("%y.%m.1")})

Add one to the revision count and prints how to reconcile git, with special
instructions if the [previous version] was from a hotfix.

Prepare a hotfix: #{__FILE__} --mode=hotfix <previous version>

Generates the next version in which to do development to complete the hotfix,
and prints git reconciliation instructions.

Prepare for next month: #{__FILE__} --mode=monthStart

Generates the next head branch for the next month, and git reconciliation
instructions.
EOF
  end
end.parse!

case options[:mode]
when 'nextVersion'
  v = if ARGV.empty?
    Revision.new(Time.now.to_date.strftime("%y.%m.1"))
  else
    Revision.new(ARGV.pop)
  end
  if v.hotfix?
    puts "Before starting coding work on #{v.nextVersion}, tag #{v} and merge it to #{v.parentBranch}, and to #{Revision.new(v.parentBranch).parentBranch} (and its descendents), then branch off #{v.parentBranch} to #{v.nextVersion}"
    puts "(But be mindful that #{v.nextVersion} might already exist, and it could be something else, or it could even be a different month!)"
  else
    puts "Before starting coding work on #{v.nextVersion}, tag #{v} and merge it to #{v.parentBranch}, then branch off #{v.parentBranch} to #{v.nextVersion}"
  end

when 'hotfix'
  if ARGV.empty?
    puts "Need to specify the version to hotfix on the command line"
    exit 1
  end
  v = Revision.new(ARGV.pop)

  puts "Before starting work on #{v.hotfix}, branch off #{v.parentBranch(true)} to #{v.hotfix}"

  #puts "Input version = #{v.to_s}, hotfix version = #{v.hotfix.to_s}"
when 'monthStart'
  v = if ARGV.empty?
    Revision.new(Time.now.to_date.strftime("%y.%m.1"))
  else
    Revision.new(ARGV.pop)
  end
  puts "Merge outstanding branches for the month into #{v.currentMonth}, and #{v.currentMonth} to master and from master to #{v.monthStart.to_s}"
end
