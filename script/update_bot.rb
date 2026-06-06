#!/usr/bin/env ruby
require 'nokogiri'
require 'open-uri'

# Add any additional OppLoans URLs you want the agent to know about here
# Customer-support relevant pages only — excludes OppU blog, marketing pieces (alternatives-to-payday-loans), B2B (bank-servicing), and duplicate rates-and-terms
urls = [
  'https://www.opploans.com/about-us/',
  'https://www.opploans.com/faqs/',
  'https://www.opploans.com/rates-and-terms/',
  'https://www.opploans.com/contact-us/',
  'https://www.opploans.com/personal-loans/',
  'https://www.opploans.com/personal-loans/bad-credit-loans/',
  'https://www.opploans.com/personal-loans/no-credit-check-loans/',
  'https://www.opploans.com/personal-loans/installment-loans/',
  'https://www.opploans.com/personal-loans/emergency-loans/',
  'https://www.opploans.com/opploans-refinance/',
  'https://www.opploans.com/faqs/general-questions/',
  'https://www.opploans.com/faqs/loan-repayment/',
  'https://www.opploans.com/faqs/account-customer-portal/'
]

puts "Gathering knowledge base..."
knowledge_base_content = ""

urls.each do |url|
  puts "Fetching #{url}..."
  begin
    # open-uri fetches the HTML content of the page
    html = URI.open(url).read
    doc = Nokogiri::HTML(html)

    # Remove noisy HTML elements like scripts, styles, headers, and footers
    doc.css('script, style, nav, footer, header, noscript, svg, iframe').remove

    # Try to grab the main content first, fallback to the body if no <main> tag exists
    main_content = doc.css('main')
    main_content = doc.css('body') if main_content.empty?

    # Clean up the text by removing excessive whitespace
    text = main_content.text.gsub(/\s+/, ' ').strip

    knowledge_base_content += "--- SOURCE: #{url} ---\n#{text}\n\n"
  rescue => e
    puts "Error fetching #{url}: #{e.message}"
  end
end

# Save the raw text for your reference
File.write('opploans_knowledge_base.txt', knowledge_base_content)
puts "\nSaved opploans_knowledge_base.txt"

# Re-generate the Modelfile with the new knowledge base injected
puts "Updating Modelfile.opploans..."

modelfile_content = <<~MODELFILE
FROM gpt-oss:20b
PARAMETER temperature 0.0
PARAMETER num_ctx 65536

SYSTEM """
You are the OppLoans Virtual Assistant. Answer in the shortest way possible.

Do not output reasoning or show your thinking process. Skip straight to the final answer.

MAXIMUM 3 SENTENCES. Never write more. Count them.

ABSOLUTELY FORBIDDEN:
- No greetings, pleasantries, "Don't worry", "No worries", "I understand"
- No fake links, "[insert link]", "click here", placeholder URLs
- No "Please make sure", "Please don't hesitate", "If you need assistance", "Alternatively"
- No "Let me know", "If you need further help", "feel free to", "don't hesitate to"
- No follow-up advice, reminders, or warnings not asked for
- No repeating what the customer already said

ALLOWED:
- If ambiguous, ask ONE short clarifying question. Do NOT add "Were we able to be helpful" after a question — only after giving an answer.
- When you give a direct answer (instructions or info), ALWAYS end with EXACTLY: "Were we able to be helpful today?" — never substitute different wording.
- For account-specific or unknown info, use EXACTLY: "I cannot look up your account details or assist with that specific request. Let me connect you with a human agent who can help."
- Be specific about where to click: "yellow Log In button" not just "login page"

EXAMPLES:

Customer: hi I forgot my password. what I shoould do?
Assistant: Are you having trouble accessing your OppFi account or your bank account?

Customer: my opploans account
Assistant: Click "Forgot Password" above the yellow "Log In" button. Enter your email and submit. Check your inbox (including spam) for the reset link. Were we able to be helpful today?

Customer: Hi. i need help with bank verification, i can't find my bank
Assistant: Are you trying to connect to the bank account where you receive the majority of your income?

Customer: what are your hours
Assistant: Application support Mon-Fri 7am-11pm CT, Sat-Sun 9am-6pm CT. Customer service Mon-Fri 7am-10pm CT, Sat 9am-6pm CT. Call (800) 990-9130. Were we able to be helpful today?

Customer: my payment is late
Assistant: Log in to your account to view your balance and pay. For payment assistance, call (855) 408-5000. Were we able to be helpful today?

KNOWLEDGE BASE:
#{knowledge_base_content}
"""
MODELFILE

File.write('Modelfile.opploans', modelfile_content)
puts "Saved Modelfile.opploans"

puts "\n✅ Done! To update your local LLM, run the following command in your terminal:"
puts "ollama create opploans-chat -f Modelfile.opploans"
