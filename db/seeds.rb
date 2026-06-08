# Seed a default Loan Advocate user if it doesn't exist
User.find_or_create_by!(email: "agent@opploans.com") do |u|
  u.name = "Jane Doe"
  u.password = "password"
  u.role = "loan_advocate"
  u.availability_status = "online"
end

puts "Database seeded: Default Agent created (agent@opploans.com / password)"
