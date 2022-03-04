require 'csv'

module DataParser
  class ParseService
    FILE_PATH='sample_military.csv'

    def self.call(args={})
      new.call(**args)
    end

    def call(destroy_all: false)
      destroy_all_discoverable if destroy_all
      CSV.foreach(
        FILE_PATH,
        col_sep: ';',
        liberal_parsing: true,
        &method(:parse_row)
      )
    end

    def destroy_all_discoverable
      Account.discoverable.find_each do |acc|
        DeleteAccountService.new.call(acc)
      end
      # User.where(account_id: Account.discoverable.ids).destroy_all
      # Account.discoverable.destroy_all
    end
    # ["Воинское звание",
    #  "Фамилия, Имя, Отчество                   ",
    #  "Воинская часть         ",
    #  "подчин",
    #  "ТВ", 4
    #  "Адрес регистрации", 5
    #  "ПочтовИндекс", 6
    #  "Регион (штат, федер. земля, пр", 7
    #  "Город                                   ", 8
    #  "Улица                  ", 9
    #  "№ дома    ", 10
    #  "Паспорт                    ", 11
    #  "Серия",
    #  "Ид. номер", 12
    #  "Кем выдан      13                                                                                     ",
    #  "Дата выдачи", 14
    #  "Ид. номер   "] 15

    # => ["Рядовой",
    #     "Пищальников Сергей Андреевич            ",
    #     "Войсковая часть 52634         ",
    #     "Лен",
    #     "52634",
    #     nil,
    #     nil,
    #     nil,
    #     nil,
    #     nil,
    #     nil,
    #     "Паспорт гражданина Российской Федерации",
    #     "22",
    #     "10689",
    #     "ОУФМС России по Нижегородской области в Автозаводском районе г. Н. Новгород                         ",
    #     "12/6/12",
    #     "525630559516"]
    #

    def build_fields(columns)
      @headers.each_with_index.map { |header, i| { name: header, value: columns[i] } }
    end

    def parse_row(columns)
      # Todo: find better way to get headers
      return @headers = columns if columns[0] == 'Воинское звание'

      ork_number = inn?(columns[15]) ? columns[15].to_i : SecureRandom.hex(7)

      info = {
        display_name: columns[1],
        username: ork_number,
        discoverable: true,
        fields: build_fields(columns)
        # fields: [{ name: "Воинское звание", value: columns[0]&.strip },
        #          { name: "Воинская часть", value: columns[2]&.strip },
        #          { name: "Подчин", value: columns[3]&.strip },
        #          { name: "Адрес регистрации", value: columns[5]&.strip },
        #          { name: "Почтовый Индекс", value: columns[6]&.strip },
        #          { name: "Паспорт", value: "#{columns[10]} #{columns[11]} #{columns[13]} #{columns[14]}"&.strip },
        #          { name: "ИНН", value: columns[15]&.strip },
        #           ],
      }

      acc = if inn?(columns[15])
              Account.where(id: columns[15].to_i).first_or_initialize(info)
            else
              Account.new(info)
            end

      # TODO: all logger here if account is no saved
      return unless acc.save

      pwd = SecureRandom.hex(10)
      user = User.create(email: "ork@#{ork_number}",
                  password: pwd,
                  password_confirmation: pwd,
                  confirmed_at: Time.now.utc,
                  account: acc,
                  approved: true,
                  agreement: true)

      # todo: it's not approved after creation somehow
      user.update(approved: true)
    end

    # Check if INN present and valid
    def inn?(inn)
      return false if inn.blank?

      inn.to_i.to_s.size == inn.size && inn.size > 4
    end
  end
end
