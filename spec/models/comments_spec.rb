# Copyright 2011-2013, The Trustees of Indiana University and Northwestern
#   University.  Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
# 
# You may obtain a copy of the License at
# 
# http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software distributed 
#   under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
#   CONDITIONS OF ANY KIND, either express or implied. See the License for the 
#   specific language governing permissions and limitations under the License.
# ---  END LICENSE_HEADER BLOCK  ---

require 'spec_helper'

describe Comment do 
  
#  subject(:comment) { Comment.new(name: "John Smith",
#      email: "john.smith@example.com",
#      email_confirmation: "john.smith@example.com",
#      subject: "Request for access",
#      comment: "This is an RSpec test") }
  
#  it {should be_valid }
  it {should validate_presence_of(:name).with_message("Name is a required field")}
  it {should validate_presence_of(:subject).with_message("Choose a subject from the dropdown menu")}
  it {should ensure_inclusion_of(:subject).in_array(Comment::SUBJECTS).with_message("Choose a subject from the dropdown menu")}
  it {should validate_presence_of(:comment).with_message("Provide a comment before submitting the form")}
  it {should validate_presence_of(:email).with_message("Email address is a required field")}

  describe "Comments" do
    it "should strip out any unsafe HTML" do
      @comment_test.comment = 
        "<script>alert('This would be an exploit')</script><p>But this is safe</p>"
      @comment_test.comment.should_not match /\<script\>.*\<\\script\>/
    end
  end
  
  describe "Email validation" do
    it "should warn if the addresses do not match" do
      @comment_test.email = "email_one@example.com"
      @comment_test.email_confirmation = "email_two@example.com"
      @comment_test.should_not be_valid
    end
    
    it "should warn if an address is invalid" do
      @comment_test.email = "nosuchemail@"
      @comment_test.should_not be_valid
    end
    
    it "should have matching email addresses" do
      @comment_test.should be_valid
    end
  end
  
  describe "Captcha" do
    it "should fail if a captcha value is entered" do
      @comment_test.nickname = 'Not empty'
      @comment_test.should_not be_valid
    end
  end
end
