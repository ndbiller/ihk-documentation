class ContractsController < ApplicationController
  include ContractsHelper

  layout 'contract'

  before_action :authenticate_admin_user!, except: [:show, :update, :download_pdf]

  [...]

  # Vertragsabschluss
  def signup_now
    @contract.calculate_sums!
    @contract.contract_is_valid = @contract.valid?

    success = false
    if @contract.save
      success = if @contract.created_account_id.present?
                  convert_account_demo_to_full
                else
                  @contract.create_user_account
                end
    end

    if success
      # Account creation successful, mark contract:
      @contract.contract_state = Contract::SIGNED
      @contract.signup_date = Time.zone.now
      @contract.save
      UserMailer.salesform_signup_done(@contract.id.to_s).deliver_later

      issue = 'Vertragsabschluss durch Callagent'
      SupportMailer.salesform_support_issue(@contract.id.to_s, issue).deliver_later

      call_to_action_onboarding

      if @contract.reload.created_account_id.present?
        sign_in :user, Account.find(@contract.created_account_id).try(:owner) unless current_admin_user.present?
        redirect_to account_welcome_path(@contract.created_account_id)
      else
        render 'signup_done', layout: 'page'
      end
    else
      render 'edit'
    end
  
  [...]

  def call_to_action_onboarding
    issue = 'Vertrag bereit für Doctena Pro Onboarding durch Onboarding Manager'
    SupportMailer.doctena_pro_onboarding(@contract.id.to_s, issue).deliver_later
  end

  [...]

  def send_user_to_bus(method, user)
    routing_key = "doxter.secretary.#{user.eid}.#{method}.de"
    puts routing_key
    BusManager::Services::TranslationAssistant.to_bus(
      user,
      routing_key
    ).translate
  end

  def send_practice_to_bus(method, practice)
    routing_key = "doxter.practice.#{practice.eid}.#{method}.de"
    puts routing_key
    BusManager::Services::TranslationAssistant.to_bus(
      practice,
      routing_key
    ).translate
  end

  def send_doctor_to_bus(method, doctor)
    routing_key = "doxter.doctor.#{doctor.eid}.#{method}.de"
    puts routing_key
    BusManager::Services::TranslationAssistant.to_bus(
      doctor,
      routing_key
    ).translate
  end

  def send_calendar_to_bus(method, calendar)
    routing_key = "doxter.agenda.#{calendar.eid}.#{method}.de"
    puts routing_key
    BusManager::Services::TranslationAssistant.to_bus(
      calendar,
      routing_key
    ).translate
  end

  [...]

  def create_address_for_bus(contract, city)
    Address.new(
      city: contract.billing_city,
      city_eid: city.eid,
      latlng: city.latlng,
      line1: contract.billing_street,
      zip: contract.billing_zip
    )
  end

  def update_address_for_bus(contract, city)
    # TODO: add functionality for more than one practice per contract
    address = contract.practices.first.address
    address.city = contract.billing_city
    address.city_eid = city.eid
    address.latlng = city.latlng
    address.line1 = contract.billing_street
    address.zip = contract.billing_zip
    address
  end

  def create_practice_for_bus(contract, address)
    Practice.new(
      address: address,
      created_at: Time.zone.now,
      eid: SecureRandom.uuid,
      fax: '',
      name: contract.practice_name,
      philosophy: '',
      phone: contract.practice_phone,
      primary_email: contract.email,
      secondary_email: '',
      updated_at: Time.zone.now,
      website: ''
    )
  end

  def update_practice_for_bus(contract, address)
    # TODO: add functionality for more than one practice per contract
    practice = contract.practices.first
    practice.address = address
    practice.fax = ''
    practice.name = contract.practice_name
    practice.philosophy = ''
    practice.phone = contract.practice_phone
    practice.primary_email = contract.email
    practice.secondary_email = ''
    practice.updated_at = Time.zone.now
    practice.website = ''
    practice
  end

  def create_user_for_bus(practice, practitioner, password)
    User.new(
      confirmed_at: Time.zone.now,  # confirmed_at equals status in pro
      created_at: Time.zone.now,
      email: practitioner.email,
      encrypted_password: password,
      first_name: practitioner.first_name,
      gender: practitioner.gender,
      last_name: practitioner.last_name,
      practice_eid: practice.eid,
      title: practitioner.title,
      updated_at: Time.zone.now
    )
  end

  def update_user_for_bus(practice, practitioner, user)
    user.confirmed_at = Time.zone.now   # confirmed_at equals status in pro
    user.email = practitioner.email
    user.first_name = practitioner.first_name
    user.gender = practitioner.gender
    user.last_name = practitioner.last_name
    user.practice_eid = practice.eid
    user.title = practitioner.title
    user.updated_at = Time.zone.now
    user
  end

  [...]

  def signup_onboarding
    # create the same initial password for all users
    password = ENV["INITIAL_ONBOARDING_PASSWORD"]
    new_hashed_password = User.new(:password => password).encrypted_password

    admin_user_mail = "team+" + @contract.email

    city = ::City.find_by(zip_codes: @contract.billing_zip)

    # practice
    if !@contract.practices.present?
      method = 'created'
      address = create_address_for_bus(@contract, city)
      practice = create_practice_for_bus(@contract, address)
      @contract.practices << practice
    else
      method = 'updated'
      address = update_address_for_bus(@contract, city)
      practice = update_practice_for_bus(@contract, address)
    end
    send_practice_to_bus(method, practice)

    # user
    if !@contract.users.present?
      method = 'created'

      @contract.practitioners.each do |practitioner|
        user = create_user_for_bus(practice, practitioner, new_hashed_password)
        @contract.users << user
        send_user_to_bus(method, user)
      end

      if @contract.practitioners.count > 1
        admin_user = create_admin_user_for_bus(@contract, practice, admin_user_mail, new_hashed_password)
        @contract.users << admin_user
        send_user_to_bus(method, admin_user)
      end
    else
      @contract.practitioners.each_with_index do |practitioner, i|
        user = @contract.users[i]

        if !user.nil?   # as long as there are the same amount of practitioners as before
          method = 'updated'
          user = update_user_for_bus(practice, practitioner, user)
          @contract.users[i] = user
        else    # when there are more users than before
          method = 'created'
          user = create_user_for_bus(practice, practitioner, new_hashed_password)
          @contract.users << user
        end

        send_user_to_bus(method, user)
      end

      if @contract.practitioners.count > 1
        admin_index = @contract.users.each_with_index do |user, i|
          return i if user.email.starts_with? 'team+'
          nil
        end

        if !admin_index.nil?
          method = 'updated'
          admin_user = update_admin_user_for_bus(@contract, admin_index, admin_user_mail, practice)
          @contract.users[admin_index] = admin_user
        else
          method = 'created'
          admin_user = create_admin_user_for_bus(@contract, practice, admin_user_mail, new_hashed_password)
          @contract.users << admin_user
        end

        send_user_to_bus(method, admin_user)
      end
    end

    # account
    account = get_account_for_bus(@contract)

    # doctor and calendar
    if !@contract.doctors.present? && !@contract.calendars.present?
      method = 'created'
      @contract.practitioners.each do |practitioner|
        doctor = create_doctor_for_bus(account, practice, practitioner)
        @contract.doctors << doctor

        calendar = create_calendar_for_bus(account, practice, practitioner, doctor)
        @contract.calendars << calendar

        send_doctor_to_bus(method, doctor)
        send_calendar_to_bus(method, calendar)
      end
    else
      @contract.practitioners.each_with_index do |practitioner, i|
        method = 'updated'

        doctor = @contract.doctors[i]
        calendar = @contract.calendars[i]

        # as long as there are the same amount of practitioners as before
        if !doctor.nil? && !calendar.nil?
          @contract.doctors[i] = update_doctor_for_bus(doctor, account, practice, practitioner)
          @contract.calendars[i] = update_calendar_for_bus(calendar, account, doctor, practice, practitioner)
        else  # if another practitioner was added
          method = 'created'

          doctor = create_doctor_for_bus(account, practice, practitioner)
          @contract.doctors << doctor

          calendar = create_calendar_for_bus(account, practice, practitioner, doctor)
          @contract.calendars << calendar
        end

        send_doctor_to_bus(method, doctor)
        send_calendar_to_bus(method, calendar)
      end
    end

    # TODO: set id from Doctena Pro after account creation is implemented
    @contract.created_pro_account_id = "some-fake-id"

    @contract.save(validate: false)

    flash.now[:notice] = "Die Daten aus Vertrag-Nr. #{@contract.contract_nr} wurden zur Doctena Pro Accounterstellung an den Bus gesendet."
    render 'offer_info', layout: 'page'
  end

  [...]

end
