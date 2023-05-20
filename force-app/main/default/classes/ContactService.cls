public class ContactService {
    private static String DEVELOPMENT_DEPARTMENT = 'Development';

    public static void updateContacts(
        Set<Id> sContactIds, String department, String phone, String email
    ) {
        List<Contact> lContacts = [SELECT Id, FirstName, LastName FROM Contact WHERE Id IN :sContactIds];
        
        for (Contact contact: lContacts) {
            contact.Department = department;
            contact.Phone = phone;
            contact.Email = email;
        }

        update lContacts;
    }
}